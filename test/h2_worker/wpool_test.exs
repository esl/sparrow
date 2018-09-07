defmodule Sparrow.H2Worker.WpoolTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @wpool_name :wpool_name
  @body "test body"

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/ConnTestHandler", Helpers.CowboyHandlers.ConnectionHandler, []},
           {"/HeaderToBodyEchoHandler",
            Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []},
           {"/TimeoutHandler", Helpers.CowboyHandlers.TimeoutHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    port = :ranch.get_port(cowboys_name)
    config = Setup.create_h2_worker_config(Setup.server_host(), port)
    :wpool.start()

    :wpool.start_pool(
      @wpool_name,
      [
        {:workers, 4},
        {:worker, {Sparrow.H2Worker, config}}
      ]
    )

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
      OuterRequest.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      :wpool.call(@wpool_name, {:send_request, request})

    length_header = {"content-length", Integer.to_string(String.length(@body))}

    assert_response_header(answer_headers, {":status", "200"})

    assert {Enum.into([length_header | headers], %{}), []} ==
             Code.eval_string(answer_body)
  end

  test "cowboy echos headers in body, certificate based authentication" do
    headers = [
      {"my_cool_header", "my_even_cooler_value"} | Setup.default_headers()
    ]

    request =
      OuterRequest.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      :wpool.call(@wpool_name, {:send_request, request})

    length_header = {"content-length", Integer.to_string(String.length(@body))}

    assert_response_header(answer_headers, {":status", "200"})

    assert {Enum.into([length_header | headers], %{}), []} ==
             Code.eval_string(answer_body)
  end

  test "cowboy replies Hello" do
    headers = Setup.default_headers()

    request = OuterRequest.new(headers, @body, "/ConnTestHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      :wpool.call(@wpool_name, {:send_request, request})

    assert_response_header(answer_headers, {":status", "200"})

    assert_response_header(
      answer_headers,
      {"content-type", "text/plain; charset=utf-8"}
    )

    assert_response_header(answer_headers, {"content-length", "5"})
    assert answer_body == "Hello"
  end

  @messages_for_pool 1_000
  @moduletag :capture_log
  test "cowboy replies Hello n times" do
    headers = Setup.default_headers()

    request = OuterRequest.new(headers, @body, "/ConnTestHandler", 2_000)

    sending_with_response = fn ->
      for _ <- 1..@messages_for_pool do
        async_wpool_call(@wpool_name, {:send_request, request})
      end

      for _ <- 1..@messages_for_pool do
        receive do
          {:ok, {answer_headers, answer_body}} ->
            increase_inner_counter()
            assert_response_header(answer_headers, {":status", "200"})
            assert answer_body == "Hello"
        after
          1000 -> :ok
        end
      end
    end

    {time, _} = :timer.tc(sending_with_response)
    # number of seconds for sending 1000 messages
    IO.inspect(time / 1_000_000)
    assert get_inner_counter() == @messages_for_pool
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end

  defp async_wpool_call(pool_name, request) do
    pid = self()

    spawn(fn ->
      send(pid, :wpool.call(pool_name, request))
    end)
  end

  defp increase_inner_counter do
    new =
      case :erlang.get(:results_counter) do
        :undefined ->
          1

        x ->
          x + 1
      end

    :erlang.put(:results_counter, new)
  end

  defp get_inner_counter do
    :erlang.get(:results_counter)
  end
end
