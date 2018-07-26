defmodule H2Integration.H2AdapterInstabilityTest do
  use ExUnit.Case
  import Mock
  alias H2Integration.Helpers.SetupHelper, as: Setup
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @port 8083

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {"/LostConnHandler", H2Integration.Helpers.CowboyHandlers.LostConnHandler, []}
         ]}
      ])
      |> Setup.start_cowboy_tls(:no, @port)

    on_exit(fn ->
      case Process.alive?(cowboy_pid) do
        true -> :cowboy.stop_listener(cowboys_name)
        _ -> :ok
      end
    end)

    :ok
  end

  test "chatterbox process die with custom reason after sending request to cowboy" do
    config = Setup.create_h2_worker_config(Setup.server_host(), @port, [], 10_000)

    worker_spec = Setup.child_spec(args: config)
    headers = Setup.default_headers()
    body = "sound of silence, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)
    conn_ref = :sys.get_state(worker_pid).connection_ref

    request = OuterRequest.new(headers, body, "/LostConnHandler", 3_000)

    spawn(fn ->
      :timer.sleep(500)
      Process.exit(conn_ref, :custom_reason)
    end)

    assert {:error, :connection_lost} == GenServer.call(worker_pid, {:send_request, request})
  end

  test "reconnecting works after connection was lost" do
    config = Setup.create_h2_worker_config(Setup.server_host(), @port, [], 10_000)

    worker_spec = Setup.child_spec(args: config)
    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)
    conn_ref = :sys.get_state(worker_pid).connection_ref

    request = OuterRequest.new(headers, body, "/LostConnHandler", 3_000)

    spawn(fn ->
      :timer.sleep(500)
      Process.exit(conn_ref, :custom_reason)
    end)

    assert {:error, :connection_lost} == GenServer.call(worker_pid, {:send_request, request})

    {:ok, {answer_headers, answer_body}} = GenServer.call(worker_pid, {:send_request, request})
    assert Enum.any?(answer_headers, &(&1 == {":status", "200"}))
    assert Enum.any?(answer_headers, &(&1 == {"content-type", "text/plain; charset=utf-8"}))
    assert Enum.any?(answer_headers, &(&1 == {"content-length", "5"}))
    assert answer_body == "Hello"
  end

  test "connecting fails works after connection was lost" do
    with_mock H2Adapter,
      open: fn _, _, _ -> {:error, :my_custom_reason} end do
      config = Setup.create_h2_worker_config(Setup.server_host(), @port, [], 10_000)

      worker_spec = Setup.child_spec(args: config)

      {error, {reason, _}} = start_supervised(worker_spec)
      assert :error == error
      assert :my_custom_reason == reason
    end
  end
end
