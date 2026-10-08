defmodule Sparrow.H2Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias Sparrow.H2ClientAdapter
  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.State

  @type config :: Sparrow.H2Worker.Config.t()
  @type state :: Sparrow.H2Worker.State.t()
  @type reason :: any
  @type request :: Sparrow.H2Worker.Request.t()
  @type from :: {pid, tag :: term}
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type response :: {:ok, {headers, body}} | {:error, reason}

  # Time to wait before sending again a request which was not sent
  @retry_delay 25

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def alive_connection?(pid) do
    GenServer.call(pid, :is_alive_connection)
  end

  @spec init(config) :: {:ok, state}
  def init(config) do
    # The connection is established in the background
    {:ok, connection_ref} = H2ClientAdapter.open(config)

    state = State.new(connection_ref, config)

    :telemetry.execute(
      [:sparrow, :h2_worker, :init],
      %{},
      worker_info(config)
    )

    {:ok, state}
  end

  @spec terminate(reason, state) :: :ok
  def terminate(reason, state) do
    H2ClientAdapter.close(state.connection_ref)

    _ =
      Logger.info("Connection shutting down",
        what: :h2_connection_terminate,
        reason: inspect(reason),
        connection_ref: inspect(state.connection_ref)
      )

    :telemetry.execute(
      [:sparrow, :h2_worker, :terminate],
      %{},
      state.config
      |> worker_info()
      |> Map.put(:reason, reason)
    )

    :ok
  end

  def handle_call(:is_alive_connection, _from, state) do
    {:reply, H2ClientAdapter.connected?(state.connection_ref), state}
  end

  @spec handle_call({:send_request, request}, from, state) :: {:noreply, state}
  def handle_call({:send_request, request}, from, state) do
    start_request(request, from, state)
    {:noreply, state}
  end

  @spec handle_cast({:send_request, request}, state) :: {:noreply, state}
  def handle_cast({:send_request, request}, state) do
    start_request(request, :noreply, state)
    {:noreply, state}
  end

  @spec handle_info(term, state) :: {:noreply, state}
  def handle_info(message, state) do
    _ =
      Logger.warning("Unknown info message",
        what: :unknown_info,
        value: message
      )

    {:noreply, state}
  end

  @spec start_request(request, from | :noreply, state) :: :ok
  defp start_request(request, from, state) do
    %State{connection_ref: connection_ref, config: config} = state
    deadline = now() + request.timeout

    # Each request is sent by its own process, which waits for the response.
    # It's not linked, so the request is completed also when the worker stops.
    {:ok, _pid} =
      Task.start(fn ->
        send_request(request, from, connection_ref, config, deadline)
      end)

    :ok
  end

  # Runs in a process started for the request
  defp send_request(request, from, connection_ref, config, deadline) do
    started_at = System.monotonic_time(:microsecond)

    response =
      try do
        headers = request_headers(request, config)
        send_with_retry(request, headers, connection_ref, deadline)
      catch
        # The caller gets a response no matter what
        kind, reason -> {:error, {kind, reason}}
      end

    time = System.monotonic_time(:microsecond) - started_at
    report(response, time, from, config)
    reply(from, response)
  end

  @spec send_with_retry(request, headers, term, integer) :: response
  defp send_with_retry(request, headers, connection_ref, deadline) do
    time_left = deadline - now()

    case H2ClientAdapter.request(
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

  defp report(response, time, from, config) do
    worker_info = worker_info(config)

    :telemetry.execute(
      [:sparrow, :h2_worker, :handle],
      %{time: time},
      worker_info
    )

    case response do
      {:ok, _response} ->
        :telemetry.execute(
          [:sparrow, :h2_worker, :request_success],
          %{},
          worker_info
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
          worker_info
          |> Map.put(:from, from)
          |> Map.put(:return_code, reason)
        )
    end
  end

  defp reply(:noreply, _response), do: :ok
  defp reply(from, response), do: GenServer.reply(from, response)

  defp now, do: System.monotonic_time(:millisecond)

  defp worker_info(config) do
    %{
      domain: config.domain,
      port: config.port,
      pool_type: config.pool_type,
      pool_name: config.pool_name,
      pool_tags: config.pool_tags
    }
  end
end
