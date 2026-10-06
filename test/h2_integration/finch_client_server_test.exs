defmodule H2Integration.FinchClientServerTest do
  use ExUnit.Case
  use AssertEventually

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @body "test body"

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    stub_with(Sparrow.H2ClientAdapter.Mock, Sparrow.H2ClientAdapter.Finch)

    if Process.whereis(Sparrow.Finch) == nil do
      start_supervised!({Finch, name: Sparrow.Finch})
    end

    cowboys_name = :"finch_cowboy_#{System.unique_integer([:positive])}"

    {:ok, cowboy_pid, ^cowboys_name} =
      [
        {":_",
         [
           {"/ConnTestHandler", Helpers.CowboyHandlers.ConnectionHandler, []},
           {"/HeaderToBodyEchoHandler",
            Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []},
           {"/EchoBodyHandler", Helpers.CowboyHandlers.EchoBodyHandler, []},
           {"/OkResponseHandler", Helpers.CowboyHandlers.OkResponseHandler, []},
           {"/ErrorResponseHandler",
            Helpers.CowboyHandlers.ErrorResponseHandler, []},
           {"/TimeoutHandler", Helpers.CowboyHandlers.TimeoutHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no, name: cowboys_name)

    on_exit(fn ->
      case Process.alive?(cowboy_pid) do
        true -> :cowboy.stop_listener(cowboys_name)
        _ -> :ok
      end
    end)

    pool_name = :"finch_pool_#{System.unique_integer([:positive])}"

    {:ok,
     port: :ranch.get_port(cowboys_name),
     cowboys_name: cowboys_name,
     pool_name: pool_name}
  end

  test "cowboy echos headers in body", context do
    pool_name = start_pool(context)

    headers = [
      {"my_cool_header", "my_even_cooler_value"} | Setup.default_headers()
    ]

    request =
      OuterRequest.new(headers, @body, "/HeaderToBodyEchoHandler", 2_000)

    assert {:ok, {answer_headers, answer_body}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, request)

    assert {":status", "200"} in answer_headers

    {echoed_headers, []} = Code.eval_string(answer_body)

    for {name, value} <- headers do
      assert echoed_headers[name] == value
    end

    assert echoed_headers["content-length"] ==
             Integer.to_string(byte_size(@body))
  end

  test "token is added to headers with token based authentication", context do
    pool_name = start_pool(context, :token_based)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        @body,
        "/HeaderToBodyEchoHandler",
        2_000
      )

    assert {:ok, {_answer_headers, answer_body}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, request)

    {echoed_headers, []} = Code.eval_string(answer_body)
    assert echoed_headers["authorization"] == "bearer dummy_token"
  end

  test "response body and headers are returned", context do
    pool_name = start_pool(context)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        @body,
        "/EchoBodyHandler",
        2_000
      )

    assert {:ok, {answer_headers, @body}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, request)

    assert {":status", "200"} in answer_headers
    assert {"content-type", "application/json; charset=UTF-8"} in answer_headers
  end

  test "empty response body is returned as empty binary", context do
    pool_name = start_pool(context)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        @body,
        "/OkResponseHandler",
        2_000
      )

    assert {:ok, {answer_headers, ""}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, request)

    assert {":status", "200"} in answer_headers
  end

  test "non 200 status is returned in headers", context do
    pool_name = start_pool(context)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        @body,
        "/ErrorResponseHandler",
        2_000
      )

    assert {:ok, {answer_headers, answer_body}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, request)

    assert {":status", "321"} in answer_headers
    assert %{"reason" => "My error reason"} == Jason.decode!(answer_body)
  end

  test "request timeouts and later ones still work", context do
    pool_name = start_pool(context)

    slow =
      OuterRequest.new(Setup.default_headers(), @body, "/TimeoutHandler", 300)

    assert {:error, :request_timeout} ==
             Sparrow.H2Worker.Pool.send_request(pool_name, slow)

    fast =
      OuterRequest.new(
        Setup.default_headers(),
        @body,
        "/ConnTestHandler",
        2_000
      )

    assert {:ok, {_headers, "Hello"}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, fast)

    # Late response to the timed out request is dropped
    Process.sleep(2_000)

    assert {:ok, {_headers, "Hello"}} =
             Sparrow.H2Worker.Pool.send_request(pool_name, fast)
  end

  test "concurrent requests on a single connection get their own responses",
       context do
    pool_name = start_pool(context)

    results =
      1..50
      |> Task.async_stream(
        fn i ->
          body = "body #{i}"

          request =
            OuterRequest.new(
              Setup.default_headers(),
              body,
              "/EchoBodyHandler",
              5_000
            )

          {body, Sparrow.H2Worker.Pool.send_request(pool_name, request)}
        end,
        max_concurrency: 50
      )
      |> Enum.map(fn {:ok, result} -> result end)

    for {body, result} <- results do
      assert {:ok, {_headers, ^body}} = result
    end
  end

  test "requests above the stream limit of the server are sent again",
       context do
    :ok = :cowboy.stop_listener(context[:cowboys_name])

    dispatch =
      :cowboy_router.compile([
        {":_",
         [{"/EchoBodyHandler", Helpers.CowboyHandlers.EchoBodyHandler, []}]}
      ])

    {:ok, _pid} =
      :cowboy.start_tls(
        context[:cowboys_name],
        [
          port: context[:port],
          certfile: "priv/ssl/fake_cert.pem",
          keyfile: "priv/ssl/fake_key.pem"
        ],
        %{env: %{dispatch: dispatch}, max_concurrent_streams: 10}
      )

    pool_name = start_pool(context)

    results =
      1..200
      |> Task.async_stream(
        fn i ->
          body = "body #{i}"

          request =
            OuterRequest.new(
              Setup.default_headers(),
              body,
              "/EchoBodyHandler",
              5_000
            )

          {body, Sparrow.H2Worker.Pool.send_request(pool_name, request)}
        end,
        max_concurrency: 200
      )
      |> Enum.map(fn {:ok, result} -> result end)

    for {body, result} <- results do
      assert {:ok, {_headers, ^body}} = result
    end
  end

  test "request which cannot be sent fails when its time is up", context do
    pool_name = start_pool(context)

    request =
      OuterRequest.new(Setup.default_headers(), @body, "/ConnTestHandler", 300)

    assert {:ok, _} = Sparrow.H2Worker.Pool.send_request(pool_name, request)
    :ok = :cowboy.stop_listener(context[:cowboys_name])

    assert_eventually(
      match?(
        {:error, reason} when reason in [:pool_not_available, :disconnected],
        Sparrow.H2Worker.Pool.send_request(pool_name, request)
      )
    )
  end

  test "requests fail when server is gone and work again when it's back",
       context do
    pool_name = start_pool(context)

    request =
      OuterRequest.new(
        Setup.default_headers(),
        @body,
        "/ConnTestHandler",
        2_000
      )

    assert {:ok, _} = Sparrow.H2Worker.Pool.send_request(pool_name, request)

    :ok = :cowboy.stop_listener(context[:cowboys_name])

    assert_eventually(
      match?(
        {:error, _},
        Sparrow.H2Worker.Pool.send_request(pool_name, request)
      )
    )

    {:ok, _pid, _name} =
      [
        {":_",
         [{"/ConnTestHandler", Helpers.CowboyHandlers.ConnectionHandler, []}]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(
        certificate_required: :no,
        name: context[:cowboys_name],
        port: context[:port]
      )

    assert_eventually(
      match?(
        {:ok, {_, "Hello"}},
        Sparrow.H2Worker.Pool.send_request(pool_name, request)
      ),
      5_000
    )
  end

  test "connection is not opened when server is unreachable", context do
    :ok = :cowboy.stop_listener(context[:cowboys_name])

    assert {:error, _reason} =
             Sparrow.H2ClientAdapter.Finch.open(
               Setup.server_host(),
               context[:port],
               verify: :verify_none
             )
  end

  defp start_pool(context, authentication \\ :certificate_based) do
    config =
      Setup.create_h2_worker_config(
        Setup.server_host(),
        context[:port],
        authentication
      )

    {:ok, _pid} =
      config
      |> Sparrow.H2Worker.Pool.Config.new(context[:pool_name], 1)
      |> Sparrow.H2Worker.Pool.start_unregistered(:fcm, [])

    context[:pool_name]
  end
end
