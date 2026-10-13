defmodule Sparrow.Pool do
  @moduledoc """
  Pool of HTTP/2 connections to a push notification service.
  """
  @type request :: Sparrow.Request.t()
  @type body :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type reason :: atom
  @type stats :: %{
          pool: atom,
          connections: pos_integer,
          connected: non_neg_integer
        }

  @type config :: Sparrow.Pool.Config.t()
  @type connection_ref :: Sparrow.Pool.Connections.connection_ref()
  @type response :: {:ok, {headers, body}} | {:error, term}

  # What is registered for a pool besides its connections. It's copied from
  # the registry for each request, so it has only what is needed to choose
  # the pool and to send requests with it.
  @typep entry :: %{
           type: Sparrow.Pool.Config.type() | nil,
           tags: [atom],
           connections: pos_integer,
           info: map,
           token_getter: (-> {String.t(), String.t()}) | nil
         }

  alias Sparrow.Pool.Config
  alias Sparrow.Pool.Connections

  require Logger

  @registry Sparrow.Pool.Registry

  # Time to wait before sending again a request which was not sent. It gets
  # longer with each attempt when there is no connection.
  @retry_delay 25
  @max_retry_delay 200

  # Time given to a request to report that its time is up
  @await_margin 1_000

  @doc """
  Sends the request and, if `is_sync` is `true`, awaits the response.

  ## Arguments

    * `pool` - name of the pool you want to send message with
    * `request` - HTTP2 request, see `Sparrow.Request`. It fails when
      the response is not received within its timeout
    * `is_sync` - if `is_sync` is `true`, awaits the response, otherwize returns `:ok`

  ## Errors

    * `{:error, {:unable_to_connect, reason}}` - the request was not sent,
      there was no connection until its time was up
    * `{:error, :connection_lost}` - the connection was lost after the request
      was sent, the response is not known
    * `{:error, :request_timeout}` - the response was not received in time
    * `{:error, :pool_not_found}` - there is no such pool
  """
  @spec send_request(atom, request, boolean()) ::
          {:ok, {headers, body}}
          | {:error, :connection_lost}
          | {:error, {:unable_to_connect, reason}}
          | {:error, :request_timeout}
          | {:error, :pool_not_found}
          | {:error, reason}
          | :ok
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
        {:exit, reason} -> {:error, {:exit, reason}}
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
    case registered(config.name) do
      nil -> start_supervisor(config)
      {owner, _value} -> {:error, {:already_started, owner}}
    end
  end

  defp start_supervisor(config) do
    children =
      Connections.child_specs(config) ++
        [
          {PartitionSupervisor,
           child_spec: Task.Supervisor, name: tasks_name(config.name)},
          # Not a process, it's run each time the processes above are started
          %{id: :connections, start: {__MODULE__, :open_connections, [config]}}
        ]

    Supervisor.start_link(children, strategy: :rest_for_one)
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
  the one which was started first is chosen. A pool keeps its place when it
  is started again with the same name.
  """
  @spec choose(Config.type(), [any]) :: atom | nil
  def choose(type, tags \\ []) do
    chosen =
      for {name, pool_tags, _order} <- pools_of_type(type),
          Enum.all?(tags, &(&1 in pool_tags)) do
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
      [:sparrow, :pools_warden, :choose_pool],
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
      {connection_ref, entry} -> stats(pool, connection_ref, entry)
    end
  end

  @doc """
  Returns `stats/1` of all pools.
  """
  @spec stats :: [stats]
  def stats do
    for {name, connection_ref, entry} <- pools() do
      stats(name, connection_ref, entry)
    end
  end

  defp stats(pool, connection_ref, entry) do
    %{
      pool: pool,
      connections: entry.connections,
      connected: Connections.connected(connection_ref)
    }
  end

  @doc false
  def open_connections(config) do
    # The connections are established in the background
    {:ok, connection_ref} = Connections.open(config)

    # It's run by the supervisor of the pool, so the pool is unregistered
    # when the supervisor stops.
    case registered(config.name) do
      nil ->
        value = {connection_ref, entry(config), order(config.name)}

        case Registry.register(@registry, config.name, value) do
          {:ok, _owner} ->
            :ignore

          {:error, {:already_registered, owner}} ->
            {:error, {:already_started, owner}}
        end

      {owner, {_connection_ref, entry, order}} when owner == self() ->
        value = {connection_ref, entry, order}

        {_new, _old} =
          Registry.update_value(@registry, config.name, fn _ -> value end)

        :ignore

      {owner, _value} ->
        {:error, {:already_started, owner}}
    end
  end

  @spec entry(config) :: entry
  defp entry(config) do
    token_getter =
      case Config.get_authentication_type(config) do
        :certificate_based -> nil
        :token_based -> config.authentication.token_getter
      end

    %{
      type: config.type,
      tags: config.tags,
      connections: config.connections,
      info: Config.pool_info(config),
      token_getter: token_getter
    }
  end

  # Pools are chosen in the order they were started for the first time. It's
  # remembered for the name of the pool, so the pool keeps its place when it
  # is started again, for example by its supervisor after a failure.
  defp order(pool) do
    case Registry.meta(@registry, {:order, pool}) do
      {:ok, order} ->
        order

      :error ->
        order = System.unique_integer([:monotonic])
        :ok = Registry.put_meta(@registry, {:order, pool}, order)
        order
    end
  end

  # All registered pools, in the order they were started
  defp pools do
    @registry
    |> Registry.select([{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.sort_by(fn {_name, {_connection_ref, _entry, order}} -> order end)
    |> Enum.map(fn {name, {connection_ref, entry, _order}} ->
      {name, connection_ref, entry}
    end)
  rescue
    # `Sparrow` application is not running
    ArgumentError -> []
  end

  # Names, tags and order of pools of given type, in the order they were
  # started. Only these are copied from the registry.
  defp pools_of_type(type) do
    pattern = {:"$1", :_, {:_, %{type: type, tags: :"$2"}, :"$3"}}

    @registry
    |> Registry.select([{pattern, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.sort_by(fn {_name, _tags, order} -> order end)
  rescue
    # `Sparrow` application is not running
    ArgumentError -> []
  end

  defp lookup(pool) do
    case registered(pool) do
      {_owner, {connection_ref, entry, _order}} -> {connection_ref, entry}
      nil -> nil
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

      {connection_ref, entry} ->
        {:ok,
         fn ->
           send_and_report(connection_ref, entry, request)
         end}
    end
  end

  # Sends the request and waits for the response, for at most the timeout
  # of the request. A request which was not sent is sent again until then.
  @spec send_and_report(connection_ref, entry, request) :: response
  defp send_and_report(connection_ref, entry, request) do
    started_at = System.monotonic_time(:microsecond)
    deadline = now() + request.timeout

    response =
      try do
        headers = request_headers(request, entry)

        send_with_retry(
          request,
          headers,
          connection_ref,
          deadline,
          @retry_delay
        )
      catch
        # The caller gets a response no matter what
        kind, reason -> {:error, {kind, reason}}
      end

    time = System.monotonic_time(:microsecond) - started_at
    report(response, time, entry.info)
    response
  end

  @spec send_with_retry(request, headers, connection_ref, integer, pos_integer) ::
          response
  defp send_with_retry(request, headers, connection_ref, deadline, delay) do
    time_left = deadline - now()

    case Connections.request(
           connection_ref,
           request.path,
           headers,
           request.body,
           max(time_left, 0)
         ) do
      {:retry, reason} when time_left > @retry_delay ->
        _ =
          Logger.debug("H2 request not sent, retrying",
            what: :h2_request_retry,
            reason: inspect(reason),
            time_left: time_left
          )

        # The last attempt has some time for the response as well
        Process.sleep(min(delay, time_left - @retry_delay))

        send_with_retry(
          request,
          headers,
          connection_ref,
          deadline,
          next_retry_delay(reason, delay)
        )

      # The server has no free streams all the time
      {:retry, :too_many_concurrent_requests} ->
        {:error, :too_many_concurrent_requests}

      # There is no connection all the time
      {:retry, reason} ->
        {:error, {:unable_to_connect, reason}}

      response ->
        response
    end
  end

  # A stream is freed as soon as any response is received
  defp next_retry_delay(:too_many_concurrent_requests, _delay), do: @retry_delay
  defp next_retry_delay(_reason, delay), do: min(2 * delay, @max_retry_delay)

  @spec request_headers(request, entry) :: headers
  defp request_headers(request, %{token_getter: nil}), do: request.headers

  defp request_headers(request, %{token_getter: token_getter}) do
    [token_getter.() | request.headers]
  end

  defp report(response, time, pool_info) do
    :telemetry.execute(
      [:sparrow, :h2_worker, :handle],
      %{time: time},
      pool_info
    )

    case response do
      {:ok, _response} ->
        :telemetry.execute(
          [:sparrow, :h2_worker, :request_success],
          %{},
          pool_info
        )

      {:error, reason} ->
        _ =
          Logger.warning("H2 request failed",
            what: :h2_request_failed,
            status: :error,
            reason: inspect(reason)
          )

        :telemetry.execute(
          [:sparrow, :h2_worker, :request_error],
          %{},
          Map.put(pool_info, :return_code, reason)
        )
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp start_task(pool, start_fun, send_fun) do
    supervisor = {:via, PartitionSupervisor, {tasks_name(pool), self()}}

    case start_fun.(supervisor, send_fun) do
      {:ok, pid} -> {:ok, pid}
      task = %Task{} -> {:ok, task}
    end
  catch
    # The pool is not running anymore
    :exit, _reason -> {:error, :pool_not_found}
  end

  defp tasks_name(pool), do: Module.concat(__MODULE__.Tasks, pool)
end
