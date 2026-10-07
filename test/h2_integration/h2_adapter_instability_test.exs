defmodule H2Integration.H2AdapterInstabilityTest do
  use ExUnit.Case
  use AssertEventually

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/LostConnHandler", Helpers.CowboyHandlers.LostConnHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    on_exit(fn ->
      case Process.alive?(cowboy_pid) do
        true -> :cowboy.stop_listener(cowboys_name)
        _ -> :ok
      end
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  test "request in progress fails when connection process is killed",
       context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])
    :ok = Setup.start_connection_processes(config)

    {:ok, worker_pid} = GenServer.start_link(Sparrow.H2Worker, config)
    eventually(assert Sparrow.H2Worker.alive_connection?(worker_pid))

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/LostConnHandler",
        3_000
      )

    kill_connection_after(worker_pid, 500)

    # Killed process doesn't report the lost requests
    assert {:error, :request_timeout} ==
             GenServer.call(worker_pid, {:send_request, request})
  end

  test "connection is restored after its process was killed", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])
    :ok = Setup.start_connection_processes(config)

    {:ok, worker_pid} = GenServer.start_link(Sparrow.H2Worker, config)
    eventually(assert Sparrow.H2Worker.alive_connection?(worker_pid))

    %{finch: finch, pool: pool} = :sys.get_state(worker_pid).connection_ref
    {:ok, connection_pid} = Finch.find_pool(finch, pool)
    # Finch pool traps exits
    Process.exit(connection_pid, :kill)

    eventually(
      assert match?(
               {:ok, new_pid} when new_pid != connection_pid,
               Finch.find_pool(finch, pool)
             )
    )

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/LostConnHandler",
        3_000
      )

    assert {:ok, {answer_headers, "Hello"}} =
             GenServer.call(worker_pid, {:send_request, request})

    assert_response_header(answer_headers, {":status", "200"})
  end

  test "connection uses the same options after its process was killed many times",
       context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])
    :ok = Setup.start_connection_processes(config)

    {:ok, worker_pid} = GenServer.start_link(Sparrow.H2Worker, config)
    %{finch: finch, pool: pool} = :sys.get_state(worker_pid).connection_ref

    # More than the restart limit of the supervisor of the connection
    for _ <- 1..6 do
      case Finch.find_pool(finch, pool) do
        {:ok, pid} -> Process.exit(pid, :kill)
        :error -> :ok
      end

      Process.sleep(100)
    end

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/LostConnHandler",
        5_000
      )

    # With other options TLS handshake fails, as server certificate is not trusted
    assert {:ok, {answer_headers, "Hello"}} =
             GenServer.call(worker_pid, {:send_request, request}, 10_000)

    assert_response_header(answer_headers, {":status", "200"})

    assert {_pid, _name, Finch.HTTP2.Pool, 1, _config} =
             Finch.Pool.Manager.get_pool_supervisor(finch, pool)
  end

  defp kill_connection_after(worker_pid, time) do
    %{finch: finch, pool: pool} = :sys.get_state(worker_pid).connection_ref
    {:ok, connection_pid} = Finch.find_pool(finch, pool)

    spawn(fn ->
      :timer.sleep(time)
      # Finch pool traps exits
      Process.exit(connection_pid, :kill)
    end)
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
