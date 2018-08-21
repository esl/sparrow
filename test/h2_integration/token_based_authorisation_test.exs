defmodule H2Integration.TokenBasedAuthorisationTest do
  use ExUnit.Case

  alias H2Integration.Helpers.TokenHelper
  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @path "/AuthenticateHandler"

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {@path, Helpers.CowboyHandlers.AuthenticateHandler, []}
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

  test "token based authorisation with correct token succeed", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    worker_spec = Setup.child_spec(args: config, name: :name)
    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)

    success_request =
      OuterRequest.new(
        [{"authorization", TokenHelper.get_correct_token()} | headers],
        body,
        @path,
        3_000
      )

    {:ok, {success_answer_headers, success_answer_body}} =
      Sparrow.H2Worker.send_request(worker_pid, success_request)

    assert_response_header(success_answer_headers, {":status", "200"})

    assert_response_header(
      success_answer_headers,
      {"content-type", "text/plain; charset=utf-8"}
    )

    assert_response_header(
      success_answer_headers,
      {"content-length",
       "#{inspect(String.length(TokenHelper.get_correct_token_response_body()))}"}
    )

    assert success_answer_body == TokenHelper.get_correct_token_response_body()
  end

  test "token based authorisation with incorrect token fails", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    worker_spec = Setup.child_spec(args: config, name: :name)
    headers = Setup.default_headers()
    body = "message, test body"

    {:ok, worker_pid} = start_supervised(worker_spec)

    fail_request =
      OuterRequest.new(
        [{"authorization", TokenHelper.get_incorrect_token()} | headers],
        body,
        @path,
        3_000
      )

    {:ok, {fail_answer_headers, fail_answer_body}} =
      Sparrow.H2Worker.send_request(worker_pid, fail_request)

    assert_response_header(fail_answer_headers, {":status", "401"})

    assert_response_header(
      fail_answer_headers,
      {"content-type", "text/plain; charset=utf-8"}
    )

    assert_response_header(
      fail_answer_headers,
      {"content-length",
       "#{
         inspect(String.length(TokenHelper.get_incorrect_token_response_body()))
       }"}
    )

    assert fail_answer_body == TokenHelper.get_incorrect_token_response_body()
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
