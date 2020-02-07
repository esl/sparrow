defmodule H2Integration.TokenBasedAuthorisationTest do
  use ExUnit.Case
  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias H2Integration.Helpers.TokenHelper
  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @path "/AuthenticateHandler"
  @pool_name :wname

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

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
    headers = Setup.default_headers()
    body = "message, test body"

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name, 4, [])
    |> Sparrow.H2Worker.Pool.start_unregistered(:fcm, [])

    success_request =
      OuterRequest.new(
        [{"authorization", TokenHelper.get_correct_token()} | headers],
        body,
        @path,
        3_000
      )

    {:ok, {success_answer_headers, success_answer_body}} =
      Sparrow.H2Worker.Pool.send_request(
        @pool_name,
        success_request,
        true
      )

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

    headers = Setup.default_headers()
    body = "message, test body"

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name, 4, [])
    |> Sparrow.H2Worker.Pool.start_unregistered(:fcm, [])

    fail_request =
      OuterRequest.new(
        [{"authorization", TokenHelper.get_incorrect_token()} | headers],
        body,
        @path,
        3_000
      )

    {:ok, {fail_answer_headers, fail_answer_body}} =
      Sparrow.H2Worker.Pool.send_request(@pool_name, fail_request)

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
