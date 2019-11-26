defmodule H2Integration.ClientServerTest do
  import Mock

  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @body "test body"
  @pool_name :name

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

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

    on_exit(fn ->
      case Process.alive?(cowboy_pid) do
        true -> :cowboy.stop_listener(cowboys_name)
        _ -> :ok
      end
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  test "cowboy echos headers in body", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    headers = [
      {"my_cool_header", "my_even_cooler_value"} | Setup.default_headers()
    ]

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name)
    |> Sparrow.H2Worker.Pool.start_link()

    request =
      OuterRequest.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.H2Worker.Pool.send_request(@pool_name, request)

    length_header = {"content-length", Integer.to_string(String.length(@body))}

    assert_response_header(answer_headers, {":status", "200"})

    assert {Enum.into([length_header | headers], %{}), []} ==
             Code.eval_string(answer_body)
  end

  test "cowboy echos headers in body, certificate based authentication",
       context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    headers = [
      {"my_cool_header", "my_even_cooler_value"} | Setup.default_headers()
    ]

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name)
    |> Sparrow.H2Worker.Pool.start_link()

    request =
      OuterRequest.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.H2Worker.Pool.send_request(@pool_name, request)

    length_header = {"content-length", Integer.to_string(String.length(@body))}

    assert_response_header(answer_headers, {":status", "200"})

    assert {Enum.into([length_header | headers], %{}), []} ==
             Code.eval_string(answer_body)
  end

  test "cowboy echos headers in body, token based authentication", context do
    config =
      Setup.create_h2_worker_config(
        Setup.server_host(),
        context[:port],
        :token_based
      )

    headers = [
      {"my_cool_header", "my_even_cooler_value"} | Setup.default_headers()
    ]

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name)
    |> Sparrow.H2Worker.Pool.start_link()

    request =
      OuterRequest.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.H2Worker.Pool.send_request(@pool_name, request)

    length_header = {"content-length", Integer.to_string(String.length(@body))}
    token_auth_header = {"authorization", "bearer dummy_token"}

    assert_response_header(answer_headers, {":status", "200"})

    assert {Enum.into([token_auth_header, length_header | headers], %{}), []} ==
             Code.eval_string(answer_body)
  end

  test "cowboy replies Hello", context do
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])
    headers = Setup.default_headers()

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name)
    |> Sparrow.H2Worker.Pool.start_link()

    request = OuterRequest.new(headers, @body, "/ConnTestHandler", 2_000)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.H2Worker.Pool.send_request(@pool_name, request)

    assert_response_header(answer_headers, {":status", "200"})

    assert_response_header(
      answer_headers,
      {"content-type", "text/plain; charset=utf-8"}
    )

    assert_response_header(answer_headers, {"content-length", "5"})
    assert answer_body == "Hello"
  end

  test "first open connection fails, second pases, certificate based authentication",
       context do
    with_mock H2Adapter,
      open: fn a, b, c ->
        case :erlang.put(:connection_count, 1) do
          :undefined -> {:error, :my_custom_reason}
          1 -> :meck.passthrough([a, b, c])
        end
      end do
      config =
        Setup.create_h2_worker_config(Setup.server_host(), context[:port])

      {:ok, pid} = GenServer.start(Sparrow.H2Worker, config)
      assert is_pid(pid)
    end
  end

  test "first open connection fails, second pases, token based authentication",
       context do
    with_mock H2Adapter,
      open: fn a, b, c ->
        case :erlang.put(:connection_count, 1) do
          :undefined -> {:error, :my_custom_reason}
          1 -> :meck.passthrough([a, b, c])
        end
      end do
      config =
        Setup.create_h2_worker_config(
          Setup.server_host(),
          context[:port],
          :token_based
        )

      {:ok, pid} = GenServer.start(Sparrow.H2Worker, config)
      assert is_pid(pid)
    end
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
