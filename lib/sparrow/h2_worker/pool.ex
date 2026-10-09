defmodule Sparrow.H2Worker.Pool do
  @moduledoc """
  Module providing functions to work on pools of HTTP/2 connections.
  """
  @type request :: Sparrow.H2Worker.Request.t()
  @type strategy ::
          :best_worker
          | :random_worker
          | :next_worker
          | :available_worker
          | :next_available_worker
  @type body :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type reason :: atom
  @type worker_config :: Sparrow.H2Worker.Config.t()
  @type pool_type :: Sparrow.PoolsWarden.pool_type()
  @type stats :: %{
          pool: atom,
          connections: pos_integer,
          connected: non_neg_integer
        }

  @type config :: Sparrow.H2Worker.Config.t()
  @type connection_ref :: Sparrow.H2ClientAdapter.Finch.connection_ref()
  @type response :: {:ok, {headers, body}} | {:error, term}

  alias Sparrow.H2ClientAdapter.Finch, as: Connections
  alias Sparrow.H2Worker.Config

  require Logger

  # Time to wait before sending again a request which was not sent
  @retry_delay 25

  @doc """
  Sends the request and, if `is_sync` is `true`, awaits the response.

  ## Arguments

    * `pool` - name of the pool you want to send message with
    * `request` - HTTP2 request, see Sparrow.H2Worker.Request
    * `is_sync` - if `is_sync` is `true`, awaits the response, otherwize returns `:ok`
    * `timeout` - time to wait for the response, works only if `is_sync` is `true`.
      The request itself fails after its own timeout, see `Sparrow.H2Worker.Request`
    * `strategy` - not used, requests are spread over the connections evenly
  """
  @spec send_request(atom, request, boolean(), non_neg_integer, strategy) ::
          {:error, :connection_lost}
          | {:ok, {headers, body}}
          | {:error, :request_timeout}
          | {:error, :pool_not_found}
          | {:error, reason}
          | :ok
  def send_request(
        pool,
        request,
        is_sync \\ true,
        timeout \\ 60_000,
        strategy \\ :random_worker
      )

  def send_request(pool, request, false, _timeout, _strategy) do
    with {:ok, send_fun} <- send_fun(pool, request),
         {:ok, _pid} <-
           start_task(pool, &Task.Supervisor.start_child/2, send_fun) do
      :ok
    end
  end

  def send_request(pool, request, true, timeout, _strategy) do
    # The request is sent by another process, so it's completed also when
    # the calling one stops waiting for the response.
    with {:ok, send_fun} <- send_fun(pool, request),
         {:ok, task} <-
           start_task(pool, &Task.Supervisor.async_nolink/2, send_fun) do
      Task.await(task, timeout)
    end
  end

  @doc """
  Function to start pool.
  """
  @spec start_unregistered(Sparrow.H2Worker.Pool.Config.t(), pool_type, [atom]) ::
          {:error, any} | {:ok, pid}
  def start_unregistered(
        config =
          %Sparrow.H2Worker.Pool.Config{
            workers_config: workers_config = %Sparrow.H2Worker.Config{}
          },
        pool_type,
        tags \\ []
      ) do
    config = %Sparrow.H2Worker.Config{
      workers_config
      | pool_type: pool_type,
        pool_name: config.pool_name,
        pool_tags: tags,
        connections: config.worker_num
    }

    children =
      Connections.child_specs(config) ++
        [
          {PartitionSupervisor,
           child_spec: Task.Supervisor, name: tasks_name(config.pool_name)},
          # Not a process, it's run each time the processes above are started
          %{id: :connections, start: {__MODULE__, :open_connections, [config]}}
        ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end

  @doc """
  Function to start pool and "register" it in pool warden.
  """
  @spec start_link(Sparrow.H2Worker.Pool.Config.t(), pool_type, [atom]) ::
          {:ok, pid}
  def start_link(config, pool_type, tags \\ []) do
    pool_name = config.pool_name
    {:ok, pid} = start_unregistered(config, pool_type, tags)
    Sparrow.PoolsWarden.add_new_pool(pid, pool_type, pool_name, tags)
    {:ok, pid}
  end

  @doc """
  Returns the number of connections of the pool and how many of them are
  established, or `nil` when there is no such pool.
  """
  @spec stats(atom) :: stats | nil
  def stats(pool) do
    case :persistent_term.get({__MODULE__, pool}, nil) do
      nil ->
        nil

      {connection_ref, config} ->
        %{
          pool: pool,
          connections: config.connections,
          connected: Connections.connected(connection_ref)
        }
    end
  end

  @doc """
  Returns `stats/1` of all pools registered in `Sparrow.PoolsWarden`.
  """
  @spec stats :: [stats]
  def stats do
    for {_pool_type, pool, _tags} <- Sparrow.PoolsWarden.pools(),
        stats = stats(pool),
        do: stats
  end

  @doc false
  def open_connections(config) do
    # The connections are established in the background
    {:ok, connection_ref} = Connections.open(config)

    :persistent_term.put(
      {__MODULE__, config.pool_name},
      {connection_ref, config}
    )

    :ignore
  end

  defp send_fun(pool, request) do
    case :persistent_term.get({__MODULE__, pool}, nil) do
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
  # of the request. A request which was not sent is sent again until then.
  @spec send_and_report(connection_ref, config, request) :: response
  defp send_and_report(connection_ref, config, request) do
    started_at = System.monotonic_time(:microsecond)
    deadline = now() + request.timeout

    response =
      try do
        headers = request_headers(request, config)
        send_with_retry(request, headers, connection_ref, deadline)
      catch
        # The caller gets a response no matter what
        kind, reason -> {:error, {kind, reason}}
      end

    time = System.monotonic_time(:microsecond) - started_at
    report(response, time, config)
    response
  end

  @spec send_with_retry(request, headers, connection_ref, integer) :: response
  defp send_with_retry(request, headers, connection_ref, deadline) do
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

        Process.sleep(@retry_delay)
        send_with_retry(request, headers, connection_ref, deadline)

      {:retry, reason} ->
        {:error, reason}

      response ->
        response
    end
  end

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
    pool_info = Config.pool_info(config)

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
