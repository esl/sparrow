defmodule H2Integration.TokenBasedAuthorisationTest do
  use ExUnit.Case
  alias H2Integration.Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias H2Integration.Helpers.TokenHelper, as: TokenHelper
  @port 8078

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {"/AuthenticateHandler", H2Integration.Helpers.CowboyHandlers.AuthenticateHandler, []}
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

  test "token based authorisation with correct token succeed" do
    config = Setup.create_h2_worker_config(Setup.server_host(), @port, [], 10_000)

    worker_spec = Setup.child_spec(args: config)
    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)

    success_request =
      OuterRequest.new(
        headers ++ [{"authorization", TokenHelper.get_correct_token()}],
        body,
        "/AuthenticateHandler",
        3_000
      )

    {:ok, {success_answer_headers, success_answer_body}} =
      GenServer.call(worker_pid, {:send_request, success_request})

    assert Enum.any?(success_answer_headers, &(&1 == {":status", "200"}))

    assert Enum.any?(
             success_answer_headers,
             &(&1 == {"content-type", "text/plain; charset=utf-8"})
           )

    assert Enum.any?(
             success_answer_headers,
             &(&1 ==
                 {"content-length",
                  "#{inspect(String.length(TokenHelper.get_correct_token_response_body()))}"})
           )

    assert success_answer_body == TokenHelper.get_correct_token_response_body()
  end

  test "token based authorisation with incorrect token fails" do
    config = Setup.create_h2_worker_config(Setup.server_host(), @port, [], 10_000)

    worker_spec = Setup.child_spec(args: config)
    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)

    fail_request =
      OuterRequest.new(
        headers ++ [{"authorization", TokenHelper.get_incorrect_token()}],
        body,
        "/AuthenticateHandler",
        3_000
      )

    {:ok, {fail_answer_headers, fail_answer_body}} =
      GenServer.call(worker_pid, {:send_request, fail_request})

    assert Enum.any?(fail_answer_headers, &(&1 == {":status", "401"}))
    assert Enum.any?(fail_answer_headers, &(&1 == {"content-type", "text/plain; charset=utf-8"}))

    assert Enum.any?(
             fail_answer_headers,
             &(&1 ==
                 {"content-length",
                  "#{inspect(String.length(TokenHelper.get_incorrect_token_response_body()))}"})
           )

    assert fail_answer_body == TokenHelper.get_incorrect_token_response_body()
  end
end
