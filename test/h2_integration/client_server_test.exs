defmodule H2Integration.ClientServerTest do
  import Mock
  use ExUnit.Case
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias H2Integration.Helpers.SetupHelper, as: Setup
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter

  @port 8079

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {"/ConnTestHandler", H2Integration.Helpers.CowboyHandlers.ConnectionHandler, []},
           {"/HeaderToBodyEchoHandler",
            H2Integration.Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []},
           {"/TimeoutHandler", H2Integration.Helpers.CowboyHandlers.TimeoutHandler, []}
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

  test "cowboy echos headers in body" do
    config = Setup.create_h2_worker_config(Setup.server_host(), @port)

    headers = Setup.default_headers() ++ [{"my_cool_header", "my_even_cooler_value"}]

    body = "test body"

    worker_spec = Setup.child_spec(args: config)
    {:ok, worker_pid} = start_supervised(worker_spec)
    request = OuterRequest.new(headers, body, "/HeaderToBodyEchoHandler", 2_000)
    {:ok, {answer_headers, answer_body}} = GenServer.call(worker_pid, {:send_request, request})
    length_header = [{"content-length", Integer.to_string(String.length(body))}]

    assert Enum.any?(answer_headers, &(&1 == {":status", "200"}))
    assert {Enum.into(headers ++ length_header, %{}), []} == Code.eval_string(answer_body)
  end

  test "cowboy replies Hello" do
    config = Setup.create_h2_worker_config(Setup.server_host(), @port)
    headers = Setup.default_headers()
    body = "another test body"

    worker_spec = Setup.child_spec(args: config, name: :worker_name)
    {:ok, worker_pid} = start_supervised(worker_spec)
    request = OuterRequest.new(headers, body, "/ConnTestHandler", 2_000)

    {:ok, {answer_headers, answer_body}} = GenServer.call(worker_pid, {:send_request, request})
    assert Enum.any?(answer_headers, &(&1 == {":status", "200"}))
    assert Enum.any?(answer_headers, &(&1 == {"content-type", "text/plain; charset=utf-8"}))
    assert Enum.any?(answer_headers, &(&1 == {"content-length", "5"}))
    assert answer_body == "Hello"
  end

  test "first open connection fails, second pases" do
    with_mock H2Adapter,
      open: fn a, b, c ->
        case :erlang.put(:connection_count, 1) do
          :undefined -> {:error, :my_custom_reason}
          1 -> :meck.passthrough([a, b, c])
        end
      end do
      config = Setup.create_h2_worker_config(Setup.server_host(), @port)

      worker_spec = Setup.child_spec(args: config)

      {:ok, pid} = start_supervised(worker_spec)
      assert is_pid(pid)
    end
  end
end
