defmodule Sparrow.H2WorkerTest do
  use ExUnit.Case
  use Quixir

  import Mock

  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias Sparrow.H2Worker.State

  @repeats 2

  setup do
    auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        "path/to/exampleName.pem",
        "path/to/exampleKey.pem"
      )

    real_auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        "test/priv/certs/Certificates1.pem",
        "test/priv/certs/key.pem"
      )

    {:ok, connection_ref: pid(), auth: auth, real_auth: real_auth}
  end

  test "server timeouts request", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 7, chars: :ascii),
            path: string(min: 3, max: 7, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: args, name: name)
        {:ok, worker_pid} = start_supervised(spec)

        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:error, :request_timeout} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)
      end
    end
  end

  test "server receives call request and returns answer", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 100
      request_timeout = 3_000
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        get_reponse: fn _, _ ->
          {:ok, {headers, body}}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, worker_pid} = start_supervised(spec)

        :erlang.send_after(1_000, worker_pid, {:END_STREAM, stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:ok, {headers, body}} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)
      end
    end
  end

  test "server receives request and returns answer posts gets error and errorcode",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65_535),
            code: int(min: 0, max: 1000),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:error, code}
        end,
        get_reponse: fn _, _ ->
          {{:ok, {headers, body}}}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, worker_pid} = start_supervised(spec)

        :erlang.send_after(150, worker_pid, {:END_STREAM, stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:error, code} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)
      end
    end
  end

  test "server receives request and expexts answer but get response returns not_ready",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        get_reponse: fn _, _ ->
          {:error, :not_ready}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config)
        {:ok, worker_pid} = start_supervised(spec)

        :erlang.send_after(150, worker_pid, {:END_STREAM, stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:error, :not_ready} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)
      end
    end
  end

  test "server receives request as cast but does not return answer", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, pid} = start_supervised(spec)

        :erlang.send_after(150, pid, {:END_STREAM, stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)
        req_result = Sparrow.H2Worker.send_request(pid, request, false)
        state = :sys.get_state(pid)
        inner_request = Map.get(state.requests, stream_id)
        assert :ok == req_result
        assert headers == inner_request.headers
        assert body == inner_request.body
        assert path == inner_request.path
      end
    end
  end

  test "END_STREAM received but request but cannot be found it in state",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ping_interval = 200

      config =
        Config.new(
          domain,
          port,
          context[:auth],
          tls_options,
          ping_interval
        )

      state = State.new(context[:connection_ref], config)

      assert {:noreply, state} ==
               Sparrow.H2Worker.handle_info({:END_STREAM, stream_id}, state)
    end
  end

  test "unexpected message received but request but cannot be found it in state",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            random_message: string(min: 10, max: 20, chars: ?a..?z)
          ],
          repeat_for: @repeats do
      ping_interval = 200

      config =
        Config.new(
          domain,
          port,
          context[:auth],
          tls_options,
          ping_interval
        )

      state = State.new(context[:connection_ref], config)

      assert {:noreply, state} ==
               Sparrow.H2Worker.handle_info(random_message, state)
    end
  end

  test "server cancel timeout on older request", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 1_000
      request_timeout = 200
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        get_reponse: fn _, _ ->
          {:ok, {headers, body}}
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: args, name: name)
        {:ok, worker_pid} = start_supervised(spec)

        :erlang.send_after(150, worker_pid, {:END_STREAM, stream_id})
        :erlang.send_after(300, worker_pid, {:END_STREAM, stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:ok, {headers, body}} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)

        assert {:ok, {headers, body}} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)

        assert {:error, :request_timeout} ==
                 Sparrow.H2Worker.send_request(worker_pid, request)
      end
    end
  end

  test "server correctly starting with succesfull connection and scheduales and runs pinging",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ponger = pid()
      ping_interval = 100

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        spec = child_spec(args: args)
        {:ok, pid} = start_supervised(spec)
        :erlang.trace(pid, true, [:receive])

        :timer.sleep(ping_interval * 2)
        assert called H2Adapter.ping(context[:connection_ref])

        assert_receive {:trace, ^pid, :receive, {:PONG, _}}
      end
    end
  end

  test "server receives down message with not conn pid", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      conn_pid = pid()
      not_conn_pid = pid()

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, conn_pid} end,
        ping: fn _ ->
          send(self(), {:PONG, conn_pid})
          :ok
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options
          )

        message = {:DOWN, make_ref(), :process, not_conn_pid, reason}
        spec = child_spec(args: args)
        {:ok, pid} = start_supervised(spec)
        :erlang.trace(pid, true, [:receive])

        before_down_message_state = :sys.get_state(pid)

        send(pid, message)

        assert_receive {:trace, ^pid, :receive, _}
        after_down_message_state = :sys.get_state(pid)
        assert before_down_message_state == after_down_message_state
      end
    end
  end

  test "request is added to state", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            body: string(min: 3, max: 15, chars: :ascii),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            port: int(min: 0, max: 65_535),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ping_interval = 100
      request_timeout = 1_000
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end do
        config =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        outer_request = OuterRequest.new(headers, body, path, request_timeout)

        {:noreply, newstate} =
          Sparrow.H2Worker.handle_call(
            {:send_request, outer_request},
            {self(), make_ref()},
            Sparrow.H2Worker.State.new(
              context[:connection_ref],
              config
            )
          )

        assert context[:connection_ref] == newstate.connection_ref
        assert config == newstate.config
        assert 1 == Enum.count(newstate.requests)
        assert [stream_id] == Map.keys(newstate.requests)
      end
    end
  end

  test "inits, succesfull connection with certificate", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ping_interval = 123

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end do
        config =
          Config.new(
            domain,
            port,
            context[:real_auth],
            tls_options,
            ping_interval
          )

        expected_config =
          Config.new(
            domain,
            port,
            context[:real_auth],
            [
              {:certfile, "test/priv/certs/Certificates1.pem"},
              {:keyfile, "test/priv/certs/key.pem"} | tls_options
            ],
            ping_interval
          )

        assert {:ok,
                Sparrow.H2Worker.State.new(
                  context[:connection_ref],
                  expected_config
                )} == Sparrow.H2Worker.init(config)
      end
    end
  end

  test "inits, succesfull connection with certificate, connection fails on send attempt",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            workers_name: atom(min: 2, max: 5),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 7, chars: :ascii),
            path: string(min: 3, max: 7, chars: :ascii)
          ],
          repeat_for: 1 do
      ping_interval = 12_300

      with_mock H2Adapter,
        open: fn _, _, _ ->
          case :erlang.get(:key) do
            :undefined ->
              :erlang.put(:key, 1)
              {:ok, context[:connection_ref]}

            1 ->
              {:error, :my_reason}
          end
        end,
        close: fn _ -> :ok end do
        headers = List.zip([headersA, headersB])

        config =
          Config.new(
            domain,
            port,
            context[:real_auth],
            tls_options,
            ping_interval
          )

        request = OuterRequest.new(headers, body, path, 1000)

        new_state = %Sparrow.H2Worker.State{
          connection_ref: nil,
          requests: [],
          config: config
        }

        {:ok, worker_pid} = Sparrow.H2Worker.start_link(workers_name, config)
        Process.unlink(worker_pid)
        :sys.replace_state(worker_pid, fn _ -> new_state end)

        assert catch_exit(
                 Sparrow.H2Worker.send_request(worker_pid, request, true)
               )
      end
    end
  end

  test "inits, succesfull connection with certificate, :noreply request is handled correctly",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 7, chars: :ascii),
            path: string(min: 3, max: 7, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: 1 do
      ping_interval = 12_300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ ->
          {:ok, context[:connection_ref]}
        end,
        get_reponse: fn _, _ -> {:ok, {headers, body}} end,
        post: fn _, _, _, _, _ -> {:ok, stream_id} end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            context[:real_auth],
            tls_options,
            ping_interval
          )

        request = OuterRequest.new(headers, body, path, 1000)

        {:ok, worker_pid} = Sparrow.H2Worker.start_link(:workers_name, config)
        Process.unlink(worker_pid)
        assert :ok == Sparrow.H2Worker.send_request(worker_pid, request, false)
        send(worker_pid, {:END_STREAM, stream_id})
        assert %{} == :sys.get_state(worker_pid).requests
        assert {:messages, []} == :erlang.process_info(self(), :messages)
        assert {:messages, []} == :erlang.process_info(worker_pid, :messages)
      end
    end
  end

  test "inits, succesfull connection with token", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ping_interval = 123

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, context[:connection_ref]} end do
        auth =
          Sparrow.H2Worker.Authentication.TokenBased.new(fn -> "dummyToken" end)

        config =
          Config.new(
            domain,
            port,
            auth,
            tls_options,
            ping_interval
          )

        assert {:ok,
                Sparrow.H2Worker.State.new(context[:connection_ref], config)} ==
                 Sparrow.H2Worker.init(config)
      end
    end
  end

  test "inits, unsuccesfull connection", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ping_interval = 123

      with_mock H2Adapter,
        open: fn _, _, _ -> {:error, reason} end do
        args =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        assert {:stop, reason} == Sparrow.H2Worker.init(args)
      end
    end
  end

  test "terminate closes connection", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      with_mock H2Adapter,
        close: fn _ -> :ok end do
        reason = "test reason"
        ping_interval = 123

        config =
          Config.new(
            domain,
            port,
            context[:auth],
            tls_options,
            ping_interval
          )

        state = Sparrow.H2Worker.State.new(context[:connection_ref], config)
        assert :ok == Sparrow.H2Worker.terminate(reason, state)
        assert called H2Adapter.close(context[:connection_ref])
      end
    end
  end

  defp pid do
    spawn(fn -> :timer.sleep(5_000) end)
  end

  defp child_spec(opts) do
    args = opts[:args]
    name = opts[:name]

    id = :rand.uniform(100_000)

    %{
      :id => id,
      :start => {Sparrow.H2Worker, :start_link, [name, args]}
    }
  end
end
