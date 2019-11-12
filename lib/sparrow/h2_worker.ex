defmodule Sparrow.H2Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.RequestSet
  alias Sparrow.H2Worker.RequestState, as: InnerRequest
  alias Sparrow.H2Worker.State

  @type gen_server_name :: atom
  @type config :: Sparrow.H2Worker.Config.t()
  @type on_start ::
          {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}
  @type init_args :: [any]
  @type state :: Sparrow.H2Worker.State.t()
  @type stream_id :: non_neg_integer
  @type reason :: any
  @type incomming_message ::
          :ping
          | {:PONG, pid}
          | {charlist, stream_id}
          | {:timeout_request, stream_id}
          | any
  @type request :: Sparrow.H2Worker.Request.t()
  @type from :: {pid, tag :: term}
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @spec init(config) :: {:ok, state, {:continue, term()}} | {:stop, reason}
  def init(config) do
    config =
      config
      |> Config.get_authentication_type()
      |> case do
        :certificate_based ->
          tls_options = [
            {:certfile, config.authentication.certfile},
            {:keyfile, config.authentication.keyfile} | config.tls_options
          ]

          %{config | tls_options: tls_options}

        :token_based ->
          config
      end
    state = Sparrow.H2Worker.State.new(nil, config)
    {:ok, state,
     {:continue, :start_conn_backoff}}
  end

  @spec terminate(reason, state) :: :ok
  def terminate(reason, %State{connection_ref: nil}) do
    _ =
      Logger.info(fn ->
        "action=terminate, reason=#{inspect(reason)}, connection_ref=nil"
      end)

    :ok
  end

  def terminate(reason, state) do
    H2Adapter.close(state.connection_ref)

    _ =
      Logger.info(fn ->
        "action=terminate, reason=#{inspect(reason)}, connection_ref!=nil"
      end)
  end

  @spec handle_continue(:start_conn_backoff, state) ::
          {:noreply, state} | {:stop, any}
  def handle_continue(:start_conn_backoff, %State{config: config}) do
    %Config{
      backoff_base: base,
      backoff_max_delay: max_delay,
      backoff_initial_delay: initial_delay
    } = config

    delay_stream =
      Stream.unfold(initial_delay, fn
        e when e * base > max_delay -> nil
        e -> {e, e * base}
      end)

    case start_conn_backoff(config, {:ok, 0}, delay_stream) do
      {:error, reason} -> {:stop, reason}
      {:ok, new_state} -> {:noreply, new_state}
    end
  end

  @spec handle_info(incomming_message, state) :: {:noreply, state}
  def handle_info(:ping, state = %State{connection_ref: nil}) do
    {:noreply, state}
  end

  def handle_info(:ping, state) do
    _ =
      if state.config.ping_interval do
        H2Adapter.ping(state.connection_ref)
        schedule_message_after(:ping, state.config.ping_interval)
      end

    {:noreply, state}
  end

  def handle_info({:PONG, from}, state) do
    _ =
      Logger.debug(fn ->
        "action=receive, item=ping_response, from=#{inspect(from)}"
      end)

    {:noreply, state}
  end

  def handle_info({:END_STREAM, stream_id}, state) do
    _ =
      Logger.debug(fn ->
        "action=receive, item=request_response, stream_id=#{inspect(stream_id)}"
      end)

    case RequestSet.get_request(state.requests, stream_id) do
      {:error, :not_found} ->
        _ =
          Logger.info(fn ->
            "Request not found in requests set stream_id=#{inspect(stream_id)}," <>
              " timed out or you are losing requests"
          end)

        :ok

      {:ok, request} ->
        _ = cancel_timer(request)
        response = H2Adapter.get_response(state.connection_ref, stream_id)
        send_response(request.from, response)
    end

    {:noreply,
     State.new(
       state.connection_ref,
       RequestSet.remove(state.requests, stream_id),
       state.config
     )}
  end

  def handle_info({:timeout_request, stream_id}, state) do
    _ =
      Logger.debug(fn ->
        "action=timeout, item=request, stream_id=#{stream_id}"
      end)

    case RequestSet.get_request(state.requests, stream_id) do
      {:error, :not_found} ->
        :ok

      {:ok, request} ->
        response = {:error, {:request_timeout, stream_id}}
        send_response(request.from, response)
    end

    {:noreply,
     State.new(
       state.connection_ref,
       RequestSet.remove(state.requests, stream_id),
       state.config
     )}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case state.connection_ref == pid do
      true ->
        _ =
          Logger.debug(fn ->
            "action=conn_shutdown, pid=#{inspect(pid)}, reason=#{
              inspect(reason)
            }"
          end)

        {:noreply, connection_closed_action(state)}

      _ ->
        _ =
          Logger.warn(fn ->
            "action=unknown_down_message, pid=#{inspect(pid)}, reason=#{
              inspect(reason)
            }"
          end)

        {:noreply, state}
    end
  end

  def handle_info(unknown, state) do
    _ = Logger.warn(fn -> "Unknown info #{inspect(unknown)}" end)
    {:noreply, state}
  end

  @doc !"""
       When connection closes, all requests in progress are teriminated with error.
       """
  @spec connection_closed_action(state) :: state
  defp connection_closed_action(state) do
    state.requests
    |> Map.to_list()
    |> Enum.each(fn {_, req} ->
      GenServer.reply(req.from, {:error, :connection_lost})
    end)

    state
    |> State.reset_connection_ref()
    |> State.reset_requests_collection()
  end

  @spec handle_call({:send_request, request}, from, state) ::
          {:noreply, state} | {:stop, reason, state}
  def handle_call({:send_request, request}, from, state) do
    _ =
      Logger.debug(fn ->
        "action=send, item=request, type=call, request=#{inspect(request)}, from=#{
          inspect(from)
        }, state=#{inspect(state)}"
      end)

    try_handle(request, from, state)
  end

  @spec handle_cast({:send_request, request}, state) ::
          {:stop, reason, state} | {:noreply, state}
  def handle_cast({:send_request, request}, state) do
    _ =
      Logger.debug(fn ->
        "action=send, item=request, type=cast, request=#{inspect(request)}, state=#{
          inspect(state)
        }"
      end)

    try_handle(request, :noreply, state)
  end

  @spec try_handle(request, from | :noreply, state) ::
          {:stop, reason, state} | {:noreply, state}
  defp try_handle(request, from, state = %State{connection_ref: nil}) do
    _ =
      Logger.info(fn ->
        "action=restarting_conn_on_new_request, request=#{inspect(request)}"
      end)

    case start_conn(state.config, state.config.reconnect_attempts) do
      {:error, reason} ->
        _ =
          Logger.error(
            "action=restarting_conn_on_new_request, result=fail, reason=#{
              inspect(reason)
            }, request=#{inspect(request)}"
          )

        {:stop, reason, state}

      {:ok, state} ->
        _ =
          Logger.info(fn ->
            "action=restarting_conn_on_new_request, result=sucess, request=#{
              inspect(request)
            }"
          end)

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
    headers =
      case Config.get_authentication_type(state.config) do
        :certificate_based ->
          request.headers

        :token_based ->
          token_header = state.config.authentication.token_getter.()

          _ =
            Logger.debug(fn ->
              "action=add_token_header_to_headers, result=sucess, token_header=#{
                inspect(token_header)
              }"
            end)

          [token_header | request.headers]
      end

    post_result =
      H2Adapter.post(
        state.connection_ref,
        state.config.domain,
        request.path,
        headers,
        request.body
      )

    case post_result do
      {:error, code} ->
        _ =
          Logger.warn(fn ->
            "action=send, item=request, request=#{inspect(request)}, status=error, reason=#{
              code
            }"
          end)

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
    _ =
      Logger.debug(fn ->
        "action=schedule, message=#{inspect(message)}, after=#{inspect(time)}"
      end)

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
    _ =
      Logger.debug(fn ->
        "action=send, item=request_response, to=nil, response=#{
          inspect(response)
        }"
      end)

    :ok
  end

  defp send_response(addressee, {:ok, {headers, body}}) do
    _ =
      Logger.debug(fn ->
        "action=send, item=request_response, to=#{inspect(addressee)}, headers=#{
          inspect(headers)
        }, body=#{body}"
      end)

    GenServer.reply(addressee, {:ok, {headers, body}})
  end

  defp send_response(addressee, {:error, reason}) do
    case reason do
      {:request_timeout, stream_id} ->
        _ =
          Logger.warn(fn ->
            "action=send, item=request_response, stream_id=#{stream_id}, status=error, reason=timeout"
          end)

        GenServer.reply(addressee, {:error, :request_timeout})

      :not_ready ->
        _ =
          Logger.error(
            "action=send, item=request_response, status=error, reason=response_not_ready"
          )

        GenServer.reply(addressee, {:error, :not_ready})

      other_reason ->
        _ =
          Logger.error(
            "action=send, item=request_response, status=error, reason=#{
              other_reason
            }"
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
      Logger.debug(fn ->
        "action=canceling_timer, request=#{inspect(request)}, result=#{
          inspect(canceling_result)
        }"
      end)

    :ok
  end

  defp start_conn_backoff(config, :error, _delay_stream) do
    case start_conn(config) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        _ =
          Logger.error(
            "action=starting_connection, domain=#{inspect(config.domain)}, port=#{
              inspect(config.port)
            }, tls_options=#{inspect(config.tls_options)}, maximum delay reached"
          )

        {:error, reason}
    end
  end

  defp start_conn_backoff(config, {:ok, delay}, delay_stream) do
    :timer.sleep(delay)

    case start_conn(config) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        new_delay = Enum.fetch(delay_stream, 0)
        start_conn_backoff(
          config, new_delay,
          Stream.drop(delay_stream, 1)
        )
    end
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
      Logger.info(fn ->
        "action=starting_connection, domain=#{inspect(config.domain)}, port=#{
          inspect(config.port)
        }, tls_options=#{inspect(config.tls_options)}, restarts_left=#{
          inspect(restarts_left)
        }"
      end)

    case start_conn(config) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        _ =
          Logger.warn(fn ->
            "action=restarting_conn, reason=#{inspect(reason)}"
          end)

        start_conn(config, restarts_left - 1)
    end
  end

  defp start_conn(config) do
    case H2Adapter.open(config.domain, config.port, config.tls_options) do
      {:ok, connection_ref} ->
        _ = schedule_message_after(:ping, config.ping_interval)
        _ = Logger.debug(fn -> "action=open_connection, result=succes" end)
        Process.monitor(connection_ref)
        Process.unlink(connection_ref)
        _ = Logger.debug(fn -> "action=starting_monitor" end)
        {:ok, State.new(connection_ref, config)}

      {:error, reason} ->
        _ =
          Logger.warn(fn ->
            "action=open_connection, result=error, reason=#{inspect(reason)}"
          end)

        {:error, reason}
    end
  end
end
