defmodule Sparrow.Pool do
  @moduledoc """
  Pool of HTTP/2 connections to a push notification service.
  """
  alias Sparrow.Pool.Config
  alias Sparrow.Pool.Connections

  require Logger

  @type request :: Sparrow.Request.t()
  @type body :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type reason :: term
  @type stats :: %{
          pool: atom,
          connections: pos_integer,
          connected: non_neg_integer
        }

  @type config :: Config.t()
  @type connection_ref :: Connections.connection_ref()
  @type response :: {:ok, {headers, body}} | {:error, term}

  @registry Sparrow.Pool.Registry

  # Time to wait before sending again a request which was not delivered. It's
  # doubled with each attempt, unless the server only had no free streams.
  @retry_delay 25
  @max_retry_delay 250

  # Time given to a request to report that its time is up
  @await_margin 1_000

  @doc """
  Sends the request and, if `is_sync` is `true`, awaits the response.

  The response is `{:ok, {headers, body}}` whatever its HTTP status is,
  the status is in the `":status"` header. When `is_sync` is `false`,
  `:ok` is returned and the result is only reported with telemetry.

  ## Errors

    * `{:error, {:unable_to_connect, reason}}` - not delivered, there was no connection in time
    * `{:error, :too_many_concurrent_requests}` - not delivered, the server had no free streams in time
    * `{:error, :connection_lost}` - sent, but the connection was lost before the response
    * `{:error, :request_timeout}` - sent, but the response did not come in time
    * `{:error, :pool_not_found}` - there is no such pool
    * `{:error, {kind, reason}}` - sending raised or exited, e.g. the
      authentication token could not be obtained

  Other errors, e.g. of Finch, are returned as they are.
  """
  @spec send_request(atom, request, boolean()) ::
          {:ok, {headers, body}} | {:error, reason} | :ok
  def send_request(pool, request, is_sync \\ true)

  def send_request(pool, request, false) do
    with {:ok, send_fun} <- send_fun(pool, request),
         {:ok, _pid} <-
           start_task(pool, &Task.Supervisor.start_child/2, send_fun) do
      :ok
    end
  end

  def send_request(pool, request, true) do
    # The request is sent by another process, so it's completed also when
    # the calling one stops waiting for the response.
    with {:ok, send_fun} <- send_fun(pool, request),
         {:ok, task} <-
           start_task(pool, &Task.Supervisor.async_nolink/2, send_fun) do
      # The request fails on its own when its time is up
      case Task.yield(task, request.timeout + @await_margin) ||
             Task.shutdown(task) do
        {:ok, response} -> response
        # The pool was stopped, the request may have been sent
        {:exit, _reason} -> {:error, :connection_lost}
        nil -> {:error, :request_timeout}
      end
    end
  end

  @doc """
  Function to start pool. `Sparrow` application must be running.

  The pool is registered under its name, which is used to send requests
  with it. It may be also found by its type and tags, see `choose/2`.
  """
  @spec start_link(config) :: Supervisor.on_start()
  def start_link(config = %Config{}) do
    value = %{
      connection_ref: Connections.connection_ref(config),
      config: config,
      # Pools are chosen in the order they were started
      order: System.unique_integer([:monotonic])
    }

    # Requests survive a restart of the connections, they're sent again
    children = [
      {Task.Supervisor, name: tasks_name(config.name)}
      | Connections.child_specs(config)
    ]

    Supervisor.start_link(children,
      strategy: :rest_for_one,
      name: {:via, Registry, {@registry, config.name, value}}
    )
  end

  @doc """
  Specification to start the pool under a supervisor.
  """
  @spec child_spec(config) :: Supervisor.child_spec()
  def child_spec(config = %Config{}) do
    %{
      id: {__MODULE__, config.name},
      start: {__MODULE__, :start_link, [config]},
      type: :supervisor
    }
  end

  @doc """
  Function to get name of a pool of certain type.

  ## Arguments
      * `type` - can be one of:
          * `:fcm` - to get FCM pool
          * `{:apns, :dev}` - to get APNS development pool
          * `{:apns, :prod}` - to get APNS production pool
      * `tags` - allows to filter pools, only pools with all of these tags are chosen

  Returns `nil` when there is no such pool. When there are many of them,
  the one which was started first is chosen.
  """
  @spec choose(Config.type(), [any]) :: atom | nil
  def choose(type, tags \\ []) do
    chosen =
      for {name, _connection_ref, config = %Config{type: ^type}} <- pools(),
          Enum.all?(tags, &(&1 in config.tags)) do
        name
      end

    chosen_pool = List.first(chosen)

    _ =
      Logger.debug("Selecting connection pool",
        what: :choose_pool,
        result: chosen,
        result_len: length(chosen)
      )

    :telemetry.execute(
      [:sparrow, :pool, :choose],
      %{},
      %{pool_name: chosen_pool, pool_type: type, pool_tags: tags}
    )

    chosen_pool
  end

  @doc """
  Returns the number of connections of the pool and how many of them are
  established, or `nil` when there is no such pool.
  """
  @spec stats(atom) :: stats | nil
  def stats(pool) do
    case lookup(pool) do
      nil -> nil
      {connection_ref, config} -> stats(pool, connection_ref, config)
    end
  end

  @doc """
  Returns `stats/1` of all pools.
  """
  @spec stats :: [stats]
  def stats do
    for {name, connection_ref, config} <- pools() do
      stats(name, connection_ref, config)
    end
  end

  defp stats(pool, connection_ref, config) do
    %{
      pool: pool,
      connections: config.connections,
      connected: Connections.connected(connection_ref)
    }
  end

  @doc false
  # Reports connection attempts of all pools as `[:sparrow, :pool, :connect]`
  @spec attach_telemetry :: :ok
  def attach_telemetry do
    _ = :telemetry.detach(__MODULE__)

    :telemetry.attach(
      __MODULE__,
      [:finch, :connect, :stop],
      &__MODULE__.handle_connect_event/4,
      nil
    )
  end

  @doc false
  def handle_connect_event(_event, measurements, metadata = %{name: finch}, _) do
    # Other Finch instances are not of any pool
    with config = %Config{} <- config_of_finch(finch) do
      result =
        case metadata do
          %{error: error} ->
            %{result: :error, reason: Connections.error_reason(error)}

          _ ->
            %{result: :ok, reason: nil}
        end

      time =
        System.convert_time_unit(measurements.duration, :native, :microsecond)

      :telemetry.execute(
        [:sparrow, :pool, :connect],
        %{time: time},
        Map.merge(Config.pool_info(config), result)
      )
    end
  end

  def handle_connect_event(_event, _measurements, _metadata, _), do: :ok

  defp config_of_finch(finch) do
    value = %{connection_ref: %{finch: finch}, config: :"$1"}

    case Registry.select(@registry, [{{:_, :_, value}, [], [:"$1"]}]) do
      [config] -> config
      [] -> nil
    end
  rescue
    # `Sparrow` application is not running
    ArgumentError -> nil
  end

  # All registered pools, in the order they were started
  defp pools do
    @registry
    |> Registry.select([{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.sort_by(fn {_name, %{order: order}} -> order end)
    |> Enum.map(fn {name, %{connection_ref: connection_ref, config: config}} ->
      {name, connection_ref, config}
    end)
  rescue
    # `Sparrow` application is not running
    ArgumentError -> []
  end

  defp lookup(pool) do
    case registered(pool) do
      {_owner, %{connection_ref: connection_ref, config: config}} ->
        {connection_ref, config}

      nil ->
        nil
    end
  end

  defp registered(pool) do
    case Registry.lookup(@registry, pool) do
      [registered] -> registered
      [] -> nil
    end
  rescue
    # `Sparrow` application is not running
    ArgumentError -> nil
  end

  defp send_fun(pool, request) do
    case lookup(pool) do
      nil ->
        {:error, :pool_not_found}

      {connection_ref, config} ->
        {:ok,
         fn ->
           send_and_report(connection_ref, config, request)
         end}
    end
  end

  # Sends the request and waits for the response, for at most the timeout
  # of the request. A request which was not delivered is sent again until then.
  @spec send_and_report(connection_ref, config, request) :: response
  defp send_and_report(connection_ref, config, request) do
    started_at = System.monotonic_time(:microsecond)
    deadline = now() + request.timeout

    response =
      try do
        headers = request_headers(request, config)
        send_with_retry(request, headers, connection_ref, config, deadline)
      catch
        # The caller gets a response no matter what
        kind, reason -> {:error, {kind, reason}}
      end

    time = System.monotonic_time(:microsecond) - started_at
    report(response, time, config)
    response
  end

  @spec send_with_retry(
          request,
          headers,
          connection_ref,
          config,
          integer,
          non_neg_integer
        ) :: response
  defp send_with_retry(
         request,
         headers,
         connection_ref,
         config,
         deadline,
         attempt \\ 0
       ) do
    case Connections.request(
           connection_ref,
           request.path,
           headers,
           request.body,
           deadline - now()
         ) do
      {:retry, reason} ->
        delay = retry_delay(reason, attempt)
        time_left = deadline - now()

        # Not sent again when its time would be up before
        if time_left > delay do
          report_retry(config, reason, attempt)

          _ =
            Logger.debug("Retrying HTTP/2 request",
              what: :http2_request_retry,
              reason: inspect(reason),
              time_left: time_left
            )

          Process.sleep(delay)

          send_with_retry(
            request,
            headers,
            connection_ref,
            config,
            deadline,
            attempt + 1
          )
        else
          not_delivered_error(reason)
        end

      response ->
        response
    end
  end

  # Reported once for the request, not for each attempt
  defp report_retry(config, reason, 0) do
    :telemetry.execute(
      [:sparrow, :pool, :retry],
      %{},
      Map.put(Config.pool_info(config), :reason, reason)
    )
  end

  defp report_retry(_config, _reason, _attempt), do: :ok

  # A stream is freed as soon as any response comes
  defp retry_delay(:too_many_concurrent_requests, _attempt), do: @retry_delay

  defp retry_delay(_reason, attempt) do
    min(@retry_delay * 2 ** attempt, @max_retry_delay)
  end

  # The server had no free streams all the time
  defp not_delivered_error(:too_many_concurrent_requests),
    do: {:error, :too_many_concurrent_requests}

  # There was no connection all the time
  defp not_delivered_error(reason), do: {:error, {:unable_to_connect, reason}}

  @spec request_headers(request, config) :: headers
  defp request_headers(request, config) do
    case Config.get_authentication_type(config) do
      :certificate_based ->
        request.headers

      :token_based ->
        [config.authentication.token_getter.() | request.headers]
    end
  end

  defp report(response, time, config) do
    result =
      case response do
        {:ok, {headers, _body}} ->
          %{result: :ok, reason: nil, status: status(headers)}

        {:error, reason} ->
          _ =
            Logger.warning("HTTP/2 request failed",
              what: :http2_request_failed,
              status: :error,
              reason: inspect(reason)
            )

          %{result: :error, reason: reason, status: nil}
      end

    :telemetry.execute(
      [:sparrow, :pool, :request],
      %{time: time},
      Map.merge(Config.pool_info(config), result)
    )
  end

  # Status of the response, `nil` when it is not known
  defp status(headers) do
    with {":status", status} <- List.keyfind(headers, ":status", 0),
         {status, ""} <- Integer.parse(status) do
      status
    else
      _ -> nil
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp start_task(pool, start_fun, send_fun) do
    case start_fun.(tasks_name(pool), send_fun) do
      {:ok, pid} -> {:ok, pid}
      task = %Task{} -> {:ok, task}
    end
  catch
    # The pool is not running anymore
    :exit, _reason -> {:error, :pool_not_found}
  end

  defp tasks_name(pool), do: Module.concat(__MODULE__.Tasks, pool)
end
