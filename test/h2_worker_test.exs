defmodule Sparrow.H2WorkerTest do
  alias Helpers.SetupHelper, as: Tools
  use ExUnit.Case
  use Quixir
  use AssertEventually

  import Mock
  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Sparrow.H2ClientAdapter.Finch, as: H2Adapter
  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias Sparrow.H2Worker.State

  alias Sparrow.H2Worker.Authentication.TokenBased, as: TokenBasedAuth
  @repeats 2

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

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
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 7, chars: :ascii),
            path: string(min: 3, max: 7, chars: :ascii),
            stream_id: int(min: 1, max: 65_535)
          ],
          repeat_for: @repeats do
      ping_interval = 100
      request_timeout = 300
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        post: fn _, _, _, _, _ ->
          {:ok, finch_ref(stream_id)}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, pid} = GenServer.start(Sparrow.H2Worker, config)
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:error, :request_timeout} ==
                 GenServer.call(pid, {:send_request, request})

        Process.exit(pid, :kill)
      end
    end
  end

  test "server receives call request and returns answer", context do
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
      ping_interval = 100
      request_timeout = 3_000
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        post: fn _, _, _, _, _ ->
          {:ok, finch_ref(stream_id)}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, worker_pid} = GenServer.start(Sparrow.H2Worker, config)

        send_response_after(1_000, worker_pid, stream_id, headers, body)
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:ok, {[{":status", "200"} | headers], body}} ==
                 GenServer.call(worker_pid, {:send_request, request})

        Process.exit(worker_pid, :kill)
      end
    end
  end

  test "server receives request and returns answer posts gets error and errorcode",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
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
      ping_interval = 100
      request_timeout = 300
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        post: fn _, _, _, _, _ ->
          {:error, code}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, worker_pid} = GenServer.start(Sparrow.H2Worker, config)

        :erlang.send_after(150, worker_pid, {finch_ref(stream_id), :done})
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:error, code} ==
                 GenServer.call(worker_pid, {:send_request, request})

        Process.exit(worker_pid, :kill)
      end
    end
  end

  test "server receives request and expexts answer but response ends before its status",
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
          repeat_for: 1 do
      ping_interval = 100
      request_timeout = 300
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        post: fn _, _, _, _, _ ->
          {:ok, finch_ref(stream_id)}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, worker_pid} = GenServer.start(Sparrow.H2Worker, config)

        :erlang.send_after(150, worker_pid, {finch_ref(stream_id), :done})
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:error, :not_ready} ==
                 GenServer.call(worker_pid, {:send_request, request})

        Process.exit(worker_pid, :kill)
      end
    end
  end

  test "server receives request as cast but does not return answer", context do
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
      ping_interval = 100
      request_timeout = 300
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        post: fn _, _, _, _, _ ->
          {:ok, finch_ref(stream_id)}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, worker_pid} = GenServer.start(Sparrow.H2Worker, config)

        :erlang.send_after(150, worker_pid, {finch_ref(stream_id), :done})
        request = OuterRequest.new(headers, body, path, request_timeout)
        req_result = GenServer.cast(worker_pid, {:send_request, request})
        state = :sys.get_state(worker_pid)
        inner_request = Map.get(state.requests, finch_ref(stream_id))
        assert :ok == req_result
        assert headers == inner_request.headers
        assert body == inner_request.body
        assert path == inner_request.path

        Process.exit(worker_pid, :kill)
      end
    end
  end

  test "end of response received but request but cannot be found it in state",
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
        Config.new(%{
          domain: domain,
          port: port,
          authentication: context[:auth],
          tls_options: tls_options,
          ping_interval: ping_interval
        })

      state = State.new(context[:connection_ref], config)

      assert {:noreply, state} ==
               Sparrow.H2Worker.handle_info(
                 {finch_ref(stream_id), :done},
                 state
               )
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
        Config.new(%{
          domain: domain,
          port: port,
          authentication: context[:auth],
          tls_options: tls_options,
          ping_interval: ping_interval
        })

      state = State.new(context[:connection_ref], config)

      assert {:noreply, state} ==
               Sparrow.H2Worker.handle_info(random_message, state)
    end
  end

  test "server cancel timeout on older request", context do
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
      ping_interval = 1_000
      request_timeout = 200
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        post: fn _, _, _, _, _ ->
          {:ok, finch_ref(stream_id)}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, worker_pid} = GenServer.start(Sparrow.H2Worker, config)

        send_response_after(150, worker_pid, stream_id, headers, body)
        send_response_after(300, worker_pid, stream_id, headers, body)
        request = OuterRequest.new(headers, body, path, request_timeout)

        assert {:ok, {[{":status", "200"} | headers], body}} ==
                 GenServer.call(worker_pid, {:send_request, request})

        assert {:ok, {[{":status", "200"} | headers], body}} ==
                 GenServer.call(worker_pid, {:send_request, request})

        assert {:error, :request_timeout} ==
                 GenServer.call(worker_pid, {:send_request, request})

        Process.exit(worker_pid, :kill)
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
      ping_interval = 100

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        {:ok, pid} = GenServer.start(Sparrow.H2Worker, config)
        :erlang.trace(pid, true, [:receive])

        :timer.sleep(ping_interval * 5)
        assert called H2Adapter.ping(context[:connection_ref])

        assert_receive {:trace, ^pid, :receive, {:ping, _}}

        Process.exit(pid, :kill)
      end
    end
  end

  test "server correctly starting with successful connection and does not schedule or runs pinging",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ping_interval = nil

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        _worker_pid = start_supervised!(Tools.h2_worker_spec(config))

        assert not called(H2Adapter.ping(context[:connection_ref]))
      end
    end
  end

  test "default ping_inerval is set correctly",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535)
          ],
          repeat_for: @repeats do
      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ ->
          :ok
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth]
          })

        worker_pid = start_supervised!(Tools.h2_worker_spec(config))
        state = :sys.get_state(worker_pid)

        assert 5000 == state.config.ping_interval
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

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, conn_pid} end,
        ping: fn _ -> :ok end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options
          })

        message = {:DOWN, make_ref(), :process, not_conn_pid, reason}

        {:ok, pid} = GenServer.start(Sparrow.H2Worker, config)
        :erlang.trace(pid, true, [:receive])

        before_down_message_state = :sys.get_state(pid)

        send(pid, message)

        assert_receive {:trace, ^pid, :receive, _}
        after_down_message_state = :sys.get_state(pid)
        assert before_down_message_state == after_down_message_state
        Process.exit(pid, :kill)
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
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        post: fn _, _, _, _, _ ->
          {:ok, finch_ref(stream_id)}
        end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

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
        assert [finch_ref(stream_id)] == Map.keys(newstate.requests)
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

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:real_auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        worker_pid = start_supervised!(Tools.h2_worker_spec(config))

        eventually(
          assert Sparrow.H2Worker.State.new(
                   context[:connection_ref],
                   config
                 ) == :sys.get_state(worker_pid, 100)
        )

        stop_h2_worker()
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
      headers = Enum.zip([headersA, headersB])

      with_mock H2Adapter, [:passthrough],
        open: fn _ ->
          {:ok, context[:connection_ref]}
        end,
        post: fn _, _, _, _, _ -> {:ok, finch_ref(stream_id)} end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        request = OuterRequest.new(headers, body, path, 1000)
        {:ok, worker_pid} = GenServer.start(Sparrow.H2Worker, config)

        assert :ok == GenServer.cast(worker_pid, {:send_request, request})

        send(worker_pid, {finch_ref(stream_id), :done})
        assert %{} == :sys.get_state(worker_pid).requests
        assert {:messages, []} == :erlang.process_info(self(), :messages)
        assert {:messages, []} == :erlang.process_info(worker_pid, :messages)
        Process.exit(worker_pid, :kill)
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

      with_mock H2Adapter, [:passthrough],
        open: fn _ -> {:ok, context[:connection_ref]} end,
        ping: fn _ -> :ok end,
        close: fn _ -> :ok end do
        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: TokenBasedAuth.new(fn -> "dummyToken" end),
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        worker_pid = start_supervised!(Tools.h2_worker_spec(config))

        eventually(
          assert Sparrow.H2Worker.State.new(
                   context[:connection_ref],
                   config
                 ) == :sys.get_state(worker_pid, 100)
        )

        stop_h2_worker()
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
      with_mock H2Adapter, [:passthrough], close: fn _ -> :ok end do
        reason = "test reason"
        ping_interval = 123

        config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            ping_interval: ping_interval
          })

        state = Sparrow.H2Worker.State.new(context[:connection_ref], config)
        assert :ok == Sparrow.H2Worker.terminate(reason, state)
        # assert called H2Adapter.close(context[:connection_ref])
      end
    end
  end

  defp pid do
    spawn(fn -> :timer.sleep(5_000) end)
  end

  describe "alive_connection?/1" do
    test "returns false when connection is not alive", context do
      ptest [
              domain: string(min: 3, max: 10, chars: ?a..?z),
              port: int(min: 0, max: 65_535),
              tls_options: list(of: atom(), min: 0, max: 3)
            ],
            repeat_for: @repeats do
        ping_interval = 123

        with_mock H2Adapter, [:passthrough],
          open: fn _ -> {:ok, context[:connection_ref]} end,
          connected?: fn _ -> false end,
          ping: fn _ -> :ok end,
          close: fn _ -> :ok end do
          config =
            Config.new(%{
              domain: domain,
              port: port,
              authentication: context[:auth],
              tls_options: tls_options,
              ping_interval: ping_interval
            })

          worker_pid = start_supervised!(Tools.h2_worker_spec(config))

          assert false == Sparrow.H2Worker.alive_connection?(worker_pid)
        end
      end
    end

    test "returns true when connection is alive", context do
      ptest [
              domain: string(min: 3, max: 10, chars: ?a..?z),
              port: int(min: 0, max: 65_535),
              tls_options: list(of: atom(), min: 0, max: 3)
            ],
            repeat_for: @repeats do
        ping_interval = 123

        with_mock H2Adapter, [:passthrough],
          open: fn _ -> {:ok, context[:connection_ref]} end,
          connected?: fn _ -> true end,
          ping: fn _ -> :ok end,
          close: fn _ -> :ok end do
          config =
            Config.new(%{
              domain: domain,
              port: port,
              authentication: TokenBasedAuth.new(fn -> "dummyToken" end),
              tls_options: tls_options,
              ping_interval: ping_interval
            })

          worker_pid = start_supervised!(Tools.h2_worker_spec(config))

          eventually(
            assert Sparrow.H2Worker.State.new(
                     context[:connection_ref],
                     config
                   ) == :sys.get_state(worker_pid, 100)
          )

          assert true == Sparrow.H2Worker.alive_connection?(worker_pid)
          stop_h2_worker()
        end
      end
    end
  end

  defp stop_h2_worker() do
    Process.get(:id)
    |> stop_supervised!()
  end

  # Shape of the request reference returned by `Finch.async_request/3`
  defp finch_ref(stream_id), do: {Finch.HTTP2.Pool, {:pool, stream_id}}

  defp send_response_after(time, worker_pid, stream_id, headers, body) do
    ref = finch_ref(stream_id)

    for part <- [{:status, 200}, {:headers, headers}, {:data, body}, :done] do
      :erlang.send_after(time, worker_pid, {ref, part})
    end
  end
end
