defmodule Sparrow.H2WorkerTest do
  use ExUnit.Case

  import Mock
  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2ClientAdapter.Finch, as: H2Adapter
  alias Sparrow.H2Worker.Authentication.CertificateBased
  alias Sparrow.H2Worker.Authentication.TokenBased
  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.Request
  alias Sparrow.H2Worker.State

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  @connection_ref :connection_ref
  @headers [{"header", "value"}]
  @response {:ok, {[{":status", "200"}], "response body"}}

  setup do
    config =
      Config.new(%{
        domain: "domain",
        port: 443,
        authentication: CertificateBased.new("cert.pem", "key.pem"),
        pool_name: :pool,
        pool_type: :fcm,
        pool_tags: [:tag]
      })

    {:ok,
     config: config, request: Request.new(@headers, "body", "/path", 1_000)}
  end

  describe "start" do
    test "opens connection with worker config", %{config: config} do
      with_adapter([], fn ->
        worker = start_worker(config)

        assert called(H2Adapter.open(config))
        assert State.new(@connection_ref, config) == :sys.get_state(worker)
      end)
    end

    test "is reported", %{config: config} do
      Setup.forward_telemetry([:sparrow, :h2_worker, :init])

      with_adapter([], fn ->
        start_worker(config)

        assert_receive {[:sparrow, :h2_worker, :init], %{},
                        %{
                          domain: "domain",
                          port: 443,
                          pool_name: :pool,
                          pool_type: :fcm,
                          pool_tags: [:tag]
                        }}
      end)
    end
  end

  describe "stop" do
    test "closes connection and is reported", %{config: config} do
      Setup.forward_telemetry([:sparrow, :h2_worker, :terminate])

      with_adapter([], fn ->
        state = State.new(@connection_ref, config)

        assert :ok == Sparrow.H2Worker.terminate(:reason, state)
        assert called(H2Adapter.close(@connection_ref))

        assert_receive {[:sparrow, :h2_worker, :terminate], %{},
                        %{pool_name: :pool, reason: :reason}}
      end)
    end
  end

  describe "alive_connection?/1" do
    test "returns true when connection is established", %{config: config} do
      with_adapter([connected?: fn @connection_ref -> true end], fn ->
        assert Sparrow.H2Worker.alive_connection?(start_worker(config))
      end)
    end

    test "returns false when connection is not established", %{config: config} do
      with_adapter([connected?: fn @connection_ref -> false end], fn ->
        refute Sparrow.H2Worker.alive_connection?(start_worker(config))
      end)
    end
  end

  describe "request sent with call" do
    test "returns response", %{config: config, request: request} do
      with_adapter([request: fn _, _, _, _, _ -> @response end], fn ->
        worker = start_worker(config)

        assert @response == GenServer.call(worker, {:send_request, request})

        assert called(
                 H2Adapter.request(
                   @connection_ref,
                   "/path",
                   @headers,
                   "body",
                   :_
                 )
               )
      end)
    end

    test "returns error", %{config: config, request: request} do
      with_adapter([request: fn _, _, _, _, _ -> {:error, :reason} end], fn ->
        worker = start_worker(config)

        assert {:error, :reason} ==
                 GenServer.call(worker, {:send_request, request})
      end)
    end

    test "is given the time it has left", %{config: config, request: request} do
      test_pid = self()

      send_timeout = fn _, _, _, _, timeout ->
        send(test_pid, {:timeout, timeout})
        @response
      end

      with_adapter([request: send_timeout], fn ->
        worker = start_worker(config)
        GenServer.call(worker, {:send_request, request})

        assert_receive {:timeout, timeout}
        assert timeout <= 1_000
        assert timeout > 900
      end)
    end

    test "doesn't block other requests", %{config: config, request: request} do
      slow_response = fn _, _, _, _, _ ->
        Process.sleep(300)
        @response
      end

      with_adapter([request: slow_response], fn ->
        worker = start_worker(config)

        {time, responses} =
          :timer.tc(fn ->
            1..10
            |> Enum.map(fn _ ->
              Task.async(fn ->
                GenServer.call(worker, {:send_request, request})
              end)
            end)
            |> Task.await_many()
          end)

        assert Enum.all?(responses, &(&1 == @response))
        assert time < 1_000_000
      end)
    end

    test "returns error when sending raises", %{
      config: config,
      request: request
    } do
      with_adapter([request: fn _, _, _, _, _ -> raise "error" end], fn ->
        worker = start_worker(config)

        assert {:error, {:error, %RuntimeError{message: "error"}}} ==
                 GenServer.call(worker, {:send_request, request})

        assert Process.alive?(worker)
      end)
    end
  end

  describe "request sent with cast" do
    test "is sent", %{config: config, request: request} do
      test_pid = self()

      notify = fn _, _, _, _, _ ->
        send(test_pid, :request_sent)
        @response
      end

      with_adapter([request: notify], fn ->
        worker = start_worker(config)

        assert :ok == GenServer.cast(worker, {:send_request, request})
        assert_receive :request_sent
        refute_receive _response, 100
      end)
    end
  end

  describe "request which was not sent" do
    test "is sent again", %{config: config, request: request} do
      {:ok, attempts} = Agent.start_link(fn -> 0 end)

      second_attempt_succeeds = fn _, _, _, _, _ ->
        case Agent.get_and_update(attempts, &{&1, &1 + 1}) do
          0 -> {:retry, :pool_not_available}
          _ -> @response
        end
      end

      with_adapter([request: second_attempt_succeeds], fn ->
        worker = start_worker(config)

        assert @response == GenServer.call(worker, {:send_request, request})
        assert 2 == Agent.get(attempts, & &1)
      end)
    end

    test "fails with the last reason when its time is up", %{config: config} do
      request = Request.new(@headers, "body", "/path", 200)
      not_sent = fn _, _, _, _, _ -> {:retry, :pool_not_available} end

      with_adapter([request: not_sent], fn ->
        worker = start_worker(config)

        {time, response} =
          :timer.tc(fn -> GenServer.call(worker, {:send_request, request}) end)

        assert {:error, :pool_not_available} == response
        assert time >= 150_000
        assert time < 1_000_000
      end)
    end
  end

  describe "authentication" do
    test "token is added to headers", %{config: config, request: request} do
      auth = TokenBased.new(fn -> {"authorization", "bearer token"} end)
      config = %{config | authentication: auth}

      with_adapter([request: fn _, _, _, _, _ -> @response end], fn ->
        worker = start_worker(config)
        GenServer.call(worker, {:send_request, request})

        assert called(
                 H2Adapter.request(
                   @connection_ref,
                   "/path",
                   [{"authorization", "bearer token"} | @headers],
                   "body",
                   :_
                 )
               )
      end)
    end

    test "request fails when token cannot be obtained", %{
      config: config,
      request: request
    } do
      auth = TokenBased.new(fn -> exit(:no_token) end)
      config = %{config | authentication: auth}

      with_adapter([request: fn _, _, _, _, _ -> @response end], fn ->
        worker = start_worker(config)

        assert {:error, {:exit, :no_token}} ==
                 GenServer.call(worker, {:send_request, request})

        assert_not_called(H2Adapter.request(:_, :_, :_, :_, :_))
      end)
    end
  end

  describe "telemetry" do
    setup do
      Setup.forward_telemetry([:sparrow, :h2_worker, :handle])
      Setup.forward_telemetry([:sparrow, :h2_worker, :request_success])
      Setup.forward_telemetry([:sparrow, :h2_worker, :request_error])
    end

    test "successful request is reported with its time", %{
      config: config,
      request: request
    } do
      slow_response = fn _, _, _, _, _ ->
        Process.sleep(50)
        @response
      end

      with_adapter([request: slow_response], fn ->
        worker = start_worker(config)
        GenServer.call(worker, {:send_request, request})

        assert_receive {[:sparrow, :h2_worker, :handle], %{time: time},
                        %{pool_name: :pool}}

        assert time >= 50_000

        assert_receive {[:sparrow, :h2_worker, :request_success], %{},
                        %{pool_name: :pool}}

        refute_receive {[:sparrow, :h2_worker, :request_error], _, _}, 50
      end)
    end

    test "failed request is reported with its reason", %{
      config: config,
      request: request
    } do
      with_adapter([request: fn _, _, _, _, _ -> {:error, :reason} end], fn ->
        worker = start_worker(config)
        GenServer.call(worker, {:send_request, request})

        assert_receive {[:sparrow, :h2_worker, :handle], %{time: _time}, _}

        assert_receive {[:sparrow, :h2_worker, :request_error], %{},
                        %{pool_name: :pool, return_code: :reason}}

        refute_receive {[:sparrow, :h2_worker, :request_success], _, _}, 50
      end)
    end
  end

  test "unexpected message is ignored", %{config: config} do
    state = State.new(@connection_ref, config)

    assert {:noreply, state} == Sparrow.H2Worker.handle_info(:message, state)
  end

  defp with_adapter(mocks, test_fun) do
    defaults = [
      open: fn _config -> {:ok, @connection_ref} end,
      close: fn _connection_ref -> :ok end
    ]

    with_mock H2Adapter, [:passthrough], Keyword.merge(defaults, mocks) do
      test_fun.()
    end
  end

  defp start_worker(config) do
    {:ok, worker} = GenServer.start(Sparrow.H2Worker, config)
    on_exit(fn -> Process.exit(worker, :kill) end)
    worker
  end
end
