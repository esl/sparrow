defmodule Sparrow.PoolTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.Request

  @pool_name :pool_name
  @body "test body"

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/ConnTestHandler", Helpers.CowboyHandlers.ConnectionHandler, []},
           {"/HeaderToBodyEchoHandler",
            Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    port = :ranch.get_port(cowboys_name)
    config = Setup.create_pool_config(Setup.server_host(), port)

    {:ok, _pid} =
      config
      |> Setup.start_pool(name: @pool_name, connections: 4, type: :fcm)

    on_exit(fn ->
      case Process.alive?(cowboy_pid) do
        true -> :cowboy.stop_listener(cowboys_name)
        _ -> :ok
      end
    end)

    {:ok, port: port}
  end

  test "cowboy echos headers in body" do
    headers = [
      {"my_cool_header", "my_even_cooler_value"} | Setup.default_headers()
    ]

    request =
      Request.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.Pool.send_request(@pool_name, request)

    length_header = {"content-length", Integer.to_string(String.length(@body))}

    assert_response_header(answer_headers, {":status", "200"})

    assert {Enum.into([length_header | headers], %{}), []} ==
             Code.eval_string(answer_body)
  end

  test "cowboy replies Hello" do
    headers = Setup.default_headers()

    request = Request.new(headers, @body, "/ConnTestHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.Pool.send_request(@pool_name, request)

    assert_response_header(answer_headers, {":status", "200"})

    assert_response_header(
      answer_headers,
      {"content-type", "text/plain; charset=utf-8"}
    )

    assert_response_header(answer_headers, {"content-length", "5"})
    assert answer_body == "Hello"
  end

  test "cowboy replies Hello async" do
    headers = Setup.default_headers()

    request = Request.new(headers, @body, "/ConnTestHandler", 2_000)

    assert :ok == Sparrow.Pool.send_request(@pool_name, request, false)
  end

  test "pool reports its connections" do
    assert %{pool: @pool_name, connections: 4} =
             Sparrow.Pool.stats(@pool_name)

    assert HelperMacros.wait_for(
             fn -> Sparrow.Pool.stats(@pool_name).connected == 4 end,
             5_000
           )
  end

  @messages_for_pool 1_000
  @moduletag :capture_log
  test "cowboy replies Hello n times" do
    headers = Setup.default_headers()

    request = Request.new(headers, @body, "/ConnTestHandler", 2_000)

    for _ <- 1..@messages_for_pool do
      async_send_request(@pool_name, request)
    end

    receive_responses(0)
  end

  # Fails on the first response which does not come in time
  defp receive_responses(@messages_for_pool), do: :ok

  defp receive_responses(received) do
    receive do
      {:ok, {answer_headers, answer_body}} ->
        assert_response_header(answer_headers, {":status", "200"})
        assert answer_body == "Hello"
        receive_responses(received + 1)

      {:error, reason} ->
        flunk("Request failed with #{inspect(reason)}")
    after
      1_000 ->
        flunk("Received #{received} of #{@messages_for_pool} responses")
    end
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end

  defp async_send_request(pool_name, request) do
    pid = self()

    spawn(fn ->
      send(pid, Sparrow.Pool.send_request(pool_name, request))
    end)
  end
end
