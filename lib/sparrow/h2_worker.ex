defmodule Sparrow.H2Worker do
  @moduledoc false
  use GenServer
  use Sparrow.Telemetry.Timer

  require Logger

  alias Sparrow.H2ClientAdapter
  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias Sparrow.H2Worker.RequestSet
  alias Sparrow.H2Worker.RequestState, as: InnerRequest
  alias Sparrow.H2Worker.State

  @type gen_server_name :: atom
  @type config :: Sparrow.H2Worker.Config.t()
  @type on_start ::
          {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}
  @type init_args :: [any]
  @type state :: Sparrow.H2Worker.State.t()
  @type stream_id :: term
  @type reason :: any
  @type incomming_message :: {:timeout_request, stream_id} | any
  @type request :: Sparrow.H2Worker.Request.t()
  @type from :: {pid, tag :: term}
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()

  # Time to wait before sending again a request which was not sent
  @retry_delay 25

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @spec init(config) :: {:ok, state}
  def init(config) do
    # The connection is established in the background
    {:ok, connection_ref} = H2ClientAdapter.open(config)

    state = State.new(connection_ref, config)

    :telemetry.execute(
      [:sparrow, :h2_worker, :init],
      %{},
      extract_worker_info(state)
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
      state
      |> extract_worker_info()
      |> Map.put(:reason, reason)
    )

    :ok
  end

  def handle_info({:timeout_request, stream_id}, state) do
    _ =
      Logger.debug("H2 request timeout",
        what: :h2_request_timeout,
        stream_id: inspect(stream_id)
      )

    case RequestSet.pop(state.requests, stream_id) do
      {nil, _requests} ->
        {:noreply, state}

      {request, requests} ->
        send_response(request.from, {:error, {:request_timeout, stream_id}})
        {:noreply, %{state | requests: requests}}
    end
  end

  def handle_info({:retry_request, request, from}, state) do
    handle(request, from, state)
  end

  @spec handle_info(incomming_message, state) :: {:noreply, state}
  def handle_info(message, state) do
    case H2ClientAdapter.handle_message(message, state.connection_ref) do
      {:response_part, stream_id, part} ->
        requests = RequestSet.add_response_part(state.requests, stream_id, part)
        {:noreply, %{state | requests: requests}}

      {:done, stream_id} ->
        finish_request(stream_id, :done, state)

      {:error, stream_id, reason} ->
        finish_request(stream_id, {:error, reason}, state)

      {:retry, stream_id, reason} ->
        retry_request(stream_id, reason, state)

      :ok ->
        {:noreply, state}

      :unknown ->
        _ =
          Logger.warning("Unknown info message",
            what: :unknown_info,
            value: message
          )

        {:noreply, state}
    end
  end

  @doc !"""
       Sends the result to the caller waiting for given stream and forgets the request.
       """
  @spec finish_request(stream_id, :done | {:error, reason}, state) ::
          {:noreply, state}
  defp finish_request(stream_id, result, state) do
    case RequestSet.pop(state.requests, stream_id) do
      {nil, _requests} ->
        _ =
          Logger.info("Received H2 response for unknown request",
            what: :unknown_h2_response_received,
            stream_id: inspect(stream_id)
          )

        {:noreply, state}

      {request, requests} ->
        _ = cancel_timer(request)
        send_response(request.from, response(result, request))
        {:noreply, %{state | requests: requests}}
    end
  end

  defp response(:done, request), do: InnerRequest.response(request)
  defp response(error = {:error, _reason}, _request), do: error

  # Sends again a request which was not sent, as long as it has time left.
  defp retry_request(stream_id, reason, state) do
    case RequestSet.pop(state.requests, stream_id) do
      {nil, _requests} ->
        {:noreply, state}

      {request, requests} ->
        time_left = :erlang.cancel_timer(request.timeout_reference)

        outer_request =
          OuterRequest.new(
            request.headers,
            request.body,
            request.path,
            time_left
          )

        schedule_retry(outer_request, request.from, reason)
        {:noreply, %{state | requests: requests}}
    end
  end

  @spec schedule_retry(request, from | :noreply, reason) :: :ok
  defp schedule_retry(
         request = %OuterRequest{timeout: time_left},
         from,
         reason
       )
       when is_integer(time_left) and time_left > @retry_delay do
    _ =
      Logger.debug("H2 request not sent, retrying",
        what: :h2_request_retry,
        reason: inspect(reason),
        time_left: time_left
      )

    request = %OuterRequest{request | timeout: time_left - @retry_delay}
    _ = schedule_message_after({:retry_request, request, from}, @retry_delay)
    :ok
  end

  defp schedule_retry(_request, from, reason) do
    send_response(from, {:error, reason})
  end

  def alive_connection?(pid) do
    GenServer.call(pid, :is_alive_connection)
  end

  def handle_call(:is_alive_connection, _from, state) do
    {:reply, H2ClientAdapter.connected?(state.connection_ref), state}
  end

  @spec handle_call({:send_request, request}, from, state) ::
          {:noreply, state} | {:stop, reason, state}
  def handle_call({:send_request, request}, from, state) do
    _ =
      Logger.debug("Attempt to send HTTP request",
        what: :h2_request_attempt,
        type: :call,
        request: request,
        from: inspect(from),
        state: state
      )

    handle(request, from, state)
  end

  @spec handle_cast({:send_request, request}, state) ::
          {:stop, reason, state} | {:noreply, state}
  def handle_cast({:send_request, request}, state) do
    _ =
      Logger.debug("Attempt to send HTTP request",
        what: :h2_request_attempt,
        type: :cast,
        request: request,
        state: state
      )

    handle(request, :noreply, state)
  end

  @doc !"""
       Tries to send request, schedulates timeout for it and adds it to state.
       """
  @timed event_tags: [:h2_worker, :handle]
  @spec handle(request, from | :noreply, state) :: {:noreply, state}
  defp handle(request, from, state) do
    headers = request_headers(request, state.config)

    post_result =
      H2ClientAdapter.post(
        state.connection_ref,
        state.config.domain,
        request.path,
        headers,
        request.body
      )

    case post_result do
      {:retry, reason} ->
        schedule_retry(request, from, reason)
        {:noreply, state}

      {:error, return_code} ->
        _ =
          Logger.warning("Failed to send H2 request",
            what: :h2_request_failed,
            request: request,
            status: :error,
            reason: inspect(return_code)
          )

        :telemetry.execute(
          [:sparrow, :h2_worker, :request_error],
          %{},
          state
          |> extract_worker_info()
          |> Map.put(:from, from)
          |> Map.put(:return_code, return_code)
        )

        send_response(from, {:error, return_code})
        {:noreply, state}

      {:ok, stream_id} ->
        request_timeout_ref =
          schedule_message_after({:timeout_request, stream_id}, request.timeout)

        new_request =
          InnerRequest.new(
            request,
            from,
            request_timeout_ref
          )

        new_state =
          State.new(
            state.connection_ref,
            RequestSet.add(state.requests, stream_id, new_request),
            state.config
          )

        :telemetry.execute(
          [:sparrow, :h2_worker, :request_success],
          %{},
          extract_worker_info(state)
        )

        {:noreply, new_state}
    end
  end

  @spec request_headers(request, config) :: headers
  defp request_headers(request, config) do
    case Config.get_authentication_type(config) do
      :certificate_based ->
        request.headers

      :token_based ->
        token_header = config.authentication.token_getter.()

        _ =
          Logger.debug("Auth token added to request headers",
            what: :add_token_to_headers,
            result: :success,
            token_header: inspect(token_header)
          )

        [token_header | request.headers]
    end
  end

  @doc !"""
       Scheduales message to genserver after time miliseconds.
       """
  @spec schedule_message_after(
          {:timeout_request, stream_id}
          | {:retry_request, request, from | :noreply},
          non_neg_integer
        ) :: reference
  defp schedule_message_after(message, time) do
    _ =
      Logger.debug("Scheduling H2 connection message",
        what: :h2_schedule_message,
        message: inspect(message),
        after: inspect(time)
      )

    :erlang.send_after(floor(time), self(), message)
  end

  @doc !"""
       Used for sending response to genserver call.
       """
  @spec send_response(
          :noreply | {pid(), any},
          {:error,
           :not_ready
           | byte()
           | {:request_timeout, stream_id}
           | {:unable_to_connect, term()}}
          | {:ok, {[any()], binary()}}
        ) :: :ok
  defp send_response(:noreply, response) do
    _ =
      Logger.debug("Sending response to caller",
        what: :h2_send_reponse,
        to: nil,
        response: inspect(response)
      )

    :ok
  end

  defp send_response(addressee, {:ok, {headers, body}}) do
    _ =
      Logger.debug("Sending response to caller",
        what: :h2_send_reponse,
        to: inspect(addressee),
        headers: inspect(headers),
        body: "#{body}"
      )

    GenServer.reply(addressee, {:ok, {headers, body}})
  end

  defp send_response(addressee, {:error, reason}) do
    case reason do
      {:request_timeout, stream_id} ->
        _ =
          Logger.warning("Sending response to caller",
            what: :h2_send_reponse,
            item: :request_response,
            stream_id: inspect(stream_id),
            status: :error,
            reason: :timeout
          )

        GenServer.reply(addressee, {:error, :request_timeout})

      :not_ready ->
        _ =
          Logger.error("Sending response to caller",
            what: :h2_send_reponse,
            status: :error,
            reason: :response_not_ready
          )

        GenServer.reply(addressee, {:error, :not_ready})

      other_reason ->
        _ =
          Logger.error("Sending response to caller",
            what: :h2_send_reponse,
            status: :error,
            reason: inspect(other_reason)
          )

        GenServer.reply(addressee, {:error, other_reason})
    end
  end

  @doc !"""
       Used for canceling timeouts for succesfully received requests.
       """
  @spec cancel_timer(Sparrow.H2Worker.RequestState.t()) :: :ok
  defp cancel_timer(request) do
    canceling_result = :erlang.cancel_timer(request.timeout_reference)

    _ =
      Logger.debug("Canceling internal H2 timer",
        what: :h2_canceling_timer,
        result: inspect(canceling_result)
      )

    :ok
  end

  defp extract_worker_info(worker_state) do
    config = worker_state.config

    %{
      domain: config.domain,
      port: config.port,
      pool_type: config.pool_type,
      pool_name: config.pool_name,
      pool_tags: config.pool_tags
    }
  end
end
