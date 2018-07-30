defmodule H2Integration.H2AdapterInstabilityTest do
  use ExUnit.Case

  import Mock

  alias H2Integration.Helpers.SetupHelper, as: Setup
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Request, as: OuterRequest

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {"/LostConnHandler", H2Integration.Helpers.CowboyHandlers.LostConnHandler, []}
         ]}
      ])
      |> Setup.start_cowboy_tls(certificate_required: :no)

    on_exit(fn ->
      case Process.alive?(cowboy_pid) do
        true -> :cowboy.stop_listener(cowboys_name)
        _ -> :ok
      end
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  test "chatterbox process die with custom reason after sending request to cowboy", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port], [], 10_000)

    worker_spec = Setup.child_spec(args: config, name: :name)
    headers = Setup.default_headers()
    body = "sound of silence, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)
    conn_ref = :sys.get_state(worker_pid).connection_ref

    request = OuterRequest.new(headers, body, "/LostConnHandler", 3_000)

    spawn(fn ->
      :timer.sleep(500)
      Process.exit(conn_ref, :custom_reason)
    end)

    assert {:error, :connection_lost} == Sparrow.H2Worker.send_request(worker_pid, request)
  end

  test "reconnecting works after connection was lost", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port], [], 10_000)

    worker_spec = Setup.child_spec(args: config, name: :name)
    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)
    conn_ref = :sys.get_state(worker_pid).connection_ref

    request = OuterRequest.new(headers, body, "/LostConnHandler", 3_000)

    spawn(fn ->
      :timer.sleep(500)
      Process.exit(conn_ref, :custom_reason)
    end)

    assert {:error, :connection_lost} == Sparrow.H2Worker.send_request(worker_pid, request)

    {:ok, {answer_headers, answer_body}} = Sparrow.H2Worker.send_request(worker_pid, request)
    assert_response_header(answer_headers, {":status", "200"})
    assert_response_header(answer_headers, {"content-type", "text/plain; charset=utf-8"})
    assert_response_header(answer_headers, {"content-length", "5"})
    assert answer_body == "Hello"
  end

  test "connecting fails works after connection was lost", context do
    with_mock H2Adapter,
      open: fn _, _, _ -> {:error, :my_custom_reason} end do
      config = Setup.create_h2_worker_config(Setup.server_host(), context[:port], [], 10_000)

      worker_spec = Setup.child_spec(args: config, name: :name)

      {error, {reason, _}} = start_supervised(worker_spec)
      assert :error == error
      assert :my_custom_reason == reason
    end
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
