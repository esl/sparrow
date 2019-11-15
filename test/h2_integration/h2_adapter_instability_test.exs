defmodule H2Integration.H2AdapterInstabilityTest do
  alias Helpers.SetupHelper, as: Tools
  use ExUnit.Case

  import Mock

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Request, as: OuterRequest

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

  test "chatterbox process die with custom reason after sending request to cowboy",
       context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    headers = Setup.default_headers()
    body = "sound of silence, test body"

    {:ok, worker_pid} = GenServer.start_link(Sparrow.H2Worker, config)
    conn_ref = :sys.get_state(worker_pid).connection_ref

    request = OuterRequest.new(headers, body, "/LostConnHandler", 3_000)

    spawn(fn ->
      :timer.sleep(500)
      Process.exit(conn_ref, :custom_reason)
    end)

    assert {:error, :connection_lost} ==
             GenServer.call(worker_pid, {:send_request, request})
  end

  test "reconnecting works after connection was lost", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = GenServer.start_link(Sparrow.H2Worker, config)
    conn_ref = :sys.get_state(worker_pid).connection_ref

    request = OuterRequest.new(headers, body, "/LostConnHandler", 3_000)

    spawn(fn ->
      :timer.sleep(500)
      Process.exit(conn_ref, :custom_reason)
    end)

    assert {:error, :connection_lost} ==
             GenServer.call(worker_pid, {:send_request, request})

    {:ok, {answer_headers, answer_body}} =
      GenServer.call(worker_pid, {:send_request, request})

    assert_response_header(answer_headers, {":status", "200"})

    assert_response_header(
      answer_headers,
      {"content-type", "text/plain; charset=utf-8"}
    )

    assert_response_header(answer_headers, {"content-length", "5"})
    assert answer_body == "Hello"
  end

  test "connecting fails works after connection was lost", context do
    with_mock H2Adapter,
      open: fn _, _, _ -> {:error, :my_custom_reason} end do
      config =
        Setup.create_h2_worker_config(Setup.server_host(), context[:port])

      worker_pid = start_supervised!(Tools.h2_worker_spec(config))
      ref = Process.monitor(worker_pid)

      :timer.sleep(1000)
      assert_receive {:DOWN, ^ref, :process, worker_pid, {:bad_return_value, {:stop, :my_custom_reason}}}
    end
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
