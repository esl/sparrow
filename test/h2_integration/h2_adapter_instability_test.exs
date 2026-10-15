defmodule H2Integration.H2AdapterInstabilityTest do
  use ExUnit.Case
  use AssertEventually

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.Request, as: OuterRequest

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/ConnTestHandler", Helpers.CowboyHandlers.ConnectionHandler, []},
           {"/NoResponseHandler", Helpers.CowboyHandlers.NoResponseHandler,
            self()}
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
    pool = start_connected_pool(context)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/NoResponseHandler",
        3_000
      )

    connection_pid = connection_pid(pool)
    caller = Task.async(fn -> Sparrow.Pool.send_request(pool, request) end)
    assert_receive {:request_received, _handler}

    # Finch pool traps exits
    Process.exit(connection_pid, :kill)

    assert {:error, :connection_lost} == Task.await(caller)
  end

  test "connection is restored after its process was killed", context do
    pool = start_connected_pool(context)
    connection_pid = connection_pid(pool)

    # Finch pool traps exits
    Process.exit(connection_pid, :kill)

    eventually(
      assert match?(
               new_pid when is_pid(new_pid) and new_pid != connection_pid,
               connection_pid(pool)
             )
    )

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/ConnTestHandler",
        3_000
      )

    assert {:ok, {answer_headers, "Hello"}} =
             Sparrow.Pool.send_request(pool, request)

    assert_response_header(answer_headers, {":status", "200"})
  end

  test "connection uses the same options after its process was killed many times",
       context do
    pool = start_connected_pool(context)
    {%{finch: finch, pool: finch_pool}, _config} = pool_data(pool)

    # More than the restart limit of the supervisor of the connection
    for _ <- 1..6 do
      case connection_pid(pool) do
        nil -> :ok
        pid -> kill_connection(pid, pool, finch, finch_pool)
      end
    end

    assert :not_found ==
             Finch.Pool.Manager.get_pool_supervisor(finch, finch_pool)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/ConnTestHandler",
        5_000
      )

    # With other options TLS handshake fails, as server certificate is not trusted
    assert {:ok, {answer_headers, "Hello"}} =
             Sparrow.Pool.send_request(pool, request)

    assert_response_header(answer_headers, {":status", "200"})

    assert {_pid, _name, Finch.HTTP2.Pool, 1, _config} =
             Finch.Pool.Manager.get_pool_supervisor(finch, finch_pool)
  end

  # Waits until the connection is restarted or its supervisor gives up
  defp kill_connection(pid, pool, finch, finch_pool) do
    # Finch pool traps exits
    Process.exit(pid, :kill)

    eventually(
      assert connection_pid(pool) not in [nil, pid] or
               :not_found ==
                 Finch.Pool.Manager.get_pool_supervisor(finch, finch_pool)
    )
  end

  defp start_connected_pool(context) do
    pool =
      Setup.server_host()
      |> Setup.create_pool_config(context[:port])
      |> Setup.start_pool_with_config()

    eventually(assert %{connected: 1} = Sparrow.Pool.stats(pool))
    pool
  end

  defp pool_data(pool) do
    [{_owner, %{connection_ref: connection_ref, config: config}}] =
      Registry.lookup(Sparrow.Pool.Registry, pool)

    {connection_ref, config}
  end

  defp connection_pid(pool) do
    {%{finch: finch, pool: finch_pool}, _config} = pool_data(pool)

    case Finch.find_pool(finch, finch_pool) do
      {:ok, pid} -> pid
      :error -> nil
    end
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
