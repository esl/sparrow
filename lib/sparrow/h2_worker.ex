defmodule Sparrow.H2Worker do
  use GenServer
  require Logger
  alias Sparrow.H2Worker.State, as: State
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.RequestSet, as: RequestSet
  alias Sparrow.H2Worker.RequestState, as: InnerRequest

  @type gen_server_name :: atom
  @type config :: Sparrow.H2Worker.Config.t()
  @type on_start :: {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}
  @type init_args :: [any]
  @type state :: Sparrow.H2Worker.State.t()
  @type stream_id :: non_neg_integer
  @type reason :: any
  @type incomming_message ::
          :ping | {:PONG, pid} | {charlist, stream_id} | {:timeout_request, stream_id} | any
  @type request :: Sparrow.H2Worker.Request.t()
  @type from :: {pid, tag :: term}
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()

  @spec send_request(pid, request) :: {:noreply, state}
  def send_request(worker, request) do
    GenServer.call(worker, {:send_request, request})
  end

  @spec start_link(gen_server_name, config) :: on_start
  def start_link(name, args) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @spec init(config) :: {:ok, state} | {:stop, reason}
  def init(config) do
    case start_conn(config, config.reconnect_attempts) do
      {:error, reason} -> {:stop, reason}
      {:ok, state} -> {:ok, state}
    end
  end

  @spec terminate(reason, state) :: :ok
  def terminate(reason, state) do
    H2Adapter.close(state.connection_ref)
    _ = Logger.info("action=terminate, reason=#{inspect(reason)}")
  end

  @spec handle_info(incomming_message, state) :: {:noreply, state}
  def handle_info(:ping, state) do
    case state.connection_ref do
      nil ->
        :ok

      _ ->
        H2Adapter.ping(state.connection_ref)
        _ = schedule_message_after(:ping, state.config.ping_interval)
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:PONG, from}, state) do
    _ = Logger.debug("action=receive, item=ping_response, from=#{inspect(from)}")
    {:noreply, state}
  end

  def handle_info({:END_STREAM, stream_id}, state) do
    _ = Logger.debug("action=receive, item=request_response, stream_id=#{inspect(stream_id)}")

    case RequestSet.get_request(state.requests, stream_id) do
      {:error, :not_found} ->
        _ = Logger.info("Request not found in requests set stream_id=#{inspect(stream_id)},
        timeouted or you are losing requests")
        :ok

      {:ok, request} ->
        _ = cancel_timer(request)
        response = H2Adapter.get_reponse(state.connection_ref, stream_id)
        send_response(request.from, response)
    end

    {:noreply,
     State.new(state.connection_ref, RequestSet.remove(state.requests, stream_id), state.config)}
  end

  def handle_info({:timeout_request, stream_id}, state) do
    _ = Logger.debug("action=timeout, item=request, stream_id=#{stream_id}")

    case RequestSet.get_request(state.requests, stream_id) do
      {:error, :not_found} ->
        :ok

      {:ok, request} ->
        response = {:error, {:request_timeout, stream_id}}
        send_response(request.from, response)
    end

    {:noreply,
     State.new(state.connection_ref, RequestSet.remove(state.requests, stream_id), state.config)}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case state.connection_ref == pid do
      true ->
        _ = Logger.debug("action=conn_shutdown, pid=#{inspect(pid)}, reason=#{inspect(reason)}")
        {:noreply, connection_closed_action(state)}

      _ ->
        _ =
          Logger.warn(
            "action=unknown_down_message, pid=#{inspect(pid)}, reason=#{inspect(reason)}"
          )

        {:noreply, state}
    end
  end

  def handle_info(unknown, state) do
    _ = Logger.warn("Unknown info #{inspect(unknown)}")
    {:noreply, state}
  end

  @doc !"""
       When connection closes, all requests in progress are teriminated with error.
       """
  @spec connection_closed_action(state) :: state
  defp connection_closed_action(state) do
    Map.to_list(state.requests)
    |> Enum.each(fn {_, req} -> GenServer.reply(req.from, {:error, :connection_lost}) end)

    state
    |> State.reset_connection_ref()
    |> State.reset_requests_collection()
  end

  @spec handle_call({:send_request, request}, from, state) :: {:noreply, state}
  def handle_call({:send_request, request}, from, state) do
    _ =
      Logger.debug(
        "action=send, item=request, type=call, request=#{inspect(request)}, from=#{inspect(from)}, state=#{
          inspect(state)
        }"
      )

    try_handle(request, from, state)
  end

  @spec handle_cast({:send_request, request}, state) :: {:stop, reason, state} | {:noreply, state}
  def handle_cast({:send_request, request}, state) do
    _ =
      Logger.debug(
        "action=send, item=request, type=cast, request=#{inspect(request)}, state=#{
          inspect(state)
        }"
      )

    try_handle(request, :noreply, state)
  end

  @spec try_handle(request, from | :noreply, state) :: {:stop, reason, state} | {:noreply, state}
  defp try_handle(request, from, state = %State{connection_ref: nil}) do
    _ = Logger.info("action=restarting_conn_on_new_request, request=#{inspect(request)}")

    case start_conn(state.config, state.config.reconnect_attempts) do
      {:error, reason} ->
        _ =
          Logger.error(
            "action=restarting_conn_on_new_request, result=fail, reason=#{inspect(reason)}, request=#{
              inspect(request)
            }"
          )

        {:stop, reason, state}

      {:ok, state} ->
        _ =
          Logger.info(
            "action=restarting_conn_on_new_request, result=sucess, request=#{inspect(request)}"
          )

        handle(request, from, state)
    end
  end

  defp try_handle(request, from, state) do
    handle(request, from, state)
  end

  @doc !"""
       Tries to send request, schedulates timeout for it and adds it to state.
       """
  @spec handle(request, from | :noreply, state) :: {:noreply, state}
  defp handle(request, from, state) do
    post_result =
      H2Adapter.post(
        state.connection_ref,
        state.config.domain,
        request.path,
        request.headers,
        request.body
      )

    case post_result do
      {:error, code} ->
        _ =
          Logger.warn(
            "action=send, item=request, request=#{inspect(request)}, status=error, reason=#{code}"
          )

        send_response(from, {:error, code})
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

        {:noreply,
         State.new(
           state.connection_ref,
           RequestSet.add(state.requests, stream_id, new_request),
           state.config
         )}
    end
  end

  @doc !"""
       Scheduales message to genserver after time miliseconds.
       When time is nil scheduling is ignored.
       """
  @spec schedule_message_after(any, nil | non_neg_integer) :: reference
  defp schedule_message_after(_message, nil) do
    :ok
  end

  defp schedule_message_after(message, time) do
    _ = Logger.debug("action=schedule, message=#{inspect(message)}, after=#{inspect(time)}")
    :erlang.send_after(time, self(), message)
  end

  @doc !"""
       Used for sending response to genserver call.
       """
  @spec send_response(
          :noreply | {pid(), any},
          {:error, :not_ready | byte() | {:request_timeout, non_neg_integer()}}
          | {:ok, {[any()], binary()}}
        ) :: :ok
  defp send_response(:noreply, response) do
    _ = Logger.debug("action=send, item=request_response, to=nil, response=#{inspect(response)}")
    :ok
  end

  defp send_response(addressee, {:ok, {headers, body}}) do
    _ =
      Logger.debug(
        "action=send, item=request_response, to=#{inspect(addressee)}, headers=#{inspect(headers)}, body=#{
          body
        }"
      )

    GenServer.reply(addressee, {:ok, {headers, body}})
  end

  defp send_response(addressee, {:error, reason}) do
    case reason do
      {:request_timeout, stream_id} ->
        _ =
          Logger.warn(
            "action=send, item=request_response, stream_id=#{stream_id}, status=error, reason=timeout"
          )

        GenServer.reply(addressee, {:error, :request_timeout})

      :not_ready ->
        _ =
          Logger.error(
            "action=send, item=request_response, status=error, reason=response_not_ready"
          )

        GenServer.reply(addressee, {:error, :not_ready})

      other_reason ->
        _ =
          Logger.error("action=send, item=request_response, status=error, reason=#{other_reason}")

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
      Logger.debug(
        "action=canceling_timer, request=#{inspect(request)}, result=#{inspect(canceling_result)}"
      )

    :ok
  end

  defp start_conn(config, 0) do
    case start_conn(config) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        _ =
          Logger.error(
            "action=starting_connection, domain=#{inspect(config.domain)}, port=#{
              inspect(config.port)
            }, tls_options=#{inspect(config.tls_options)}, restarts_left=0"
          )

        {:error, reason}
    end
  end

  defp start_conn(config, restarts_left) when restarts_left > 0 do
    _ =
      Logger.info(
        "action=starting_connection, domain=#{inspect(config.domain)}, port=#{
          inspect(config.port)
        }, tls_options=#{inspect(config.tls_options)}, restarts_left=#{inspect(restarts_left)}"
      )

    case start_conn(config) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        _ = Logger.warn("action=restarting_conn, reason=#{inspect(reason)}")
        start_conn(config, restarts_left - 1)
    end
  end

  defp start_conn(config) do
    case H2Adapter.open(config.domain, config.port, config.tls_options) do
      {:ok, connection_ref} ->
        _ = schedule_message_after(:ping, config.ping_interval)
        _ = Logger.debug("action=open_connection, result=succes")
        Process.monitor(connection_ref)
        Process.unlink(connection_ref)
        _ = Logger.debug("action=starting_monitor")
        {:ok, State.new(connection_ref, config)}

      {:error, reason} ->
        _ = Logger.warn("action=open_connection, result=error, reason=#{inspect(reason)}")
        {:error, reason}
    end
  end
end
