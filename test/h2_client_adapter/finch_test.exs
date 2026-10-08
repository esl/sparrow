defmodule H2ClientAdapter.FinchTest do
  use ExUnit.Case

  alias Sparrow.H2ClientAdapter.Finch, as: H2Adapter

  import Mock

  @conn %{
    finch: Sparrow.Finch.Pool,
    pool: Finch.Pool.new("https://localhost:443"),
    base_url: "https://localhost:443",
    strategy: {Finch.Pool.Strategy.RoundRobin, :counter}
  }

  describe "request" do
    test "is sent to the connection with its timeout" do
      test_pid = self()

      respond = fn request, finch, opts ->
        send(test_pid, {:request, request, finch, opts})
        {:ok, %Finch.Response{status: 200, headers: [], body: ""}}
      end

      with_mock Finch, [:passthrough], request: respond do
        request(250)

        assert_receive {:request, request, Sparrow.Finch.Pool,
                        [
                          receive_timeout: 250,
                          pool_strategy:
                            {Finch.Pool.Strategy.RoundRobin, :counter}
                        ]}

        assert %Finch.Request{
                 method: "POST",
                 scheme: :https,
                 host: "localhost",
                 port: 443,
                 path: "/path",
                 headers: [{"content-length", "4"}, {"header", "value"}],
                 body: "body"
               } = request
      end
    end

    test "returns response with its status as a header" do
      response = %Finch.Response{
        status: 410,
        headers: [{"apns-id", "1"}],
        body: "response body"
      }

      with_mock Finch, [:passthrough],
        request: fn _, _, _ -> {:ok, response} end do
        assert {:ok, {[{":status", "410"}, {"apns-id", "1"}], "response body"}} ==
                 request()
      end
    end

    test "can be retried when it was not sent" do
      for reason <- [
            :pool_not_available,
            :disconnected,
            :connection_not_ready,
            :read_only,
            :unprocessed,
            :too_many_concurrent_requests
          ] do
        assert {:retry, reason} == request_failing_with(reason)
      end
    end

    test "fails when it might have been sent" do
      assert {:error, :closed} == request_failing_with(:closed)

      assert {:error, :connection_closed} ==
               request_failing_with(:connection_closed)
    end

    test "fails with request_timeout when response is not received in time" do
      assert {:error, :request_timeout} == request_failing_with(:timeout)
    end

    test "fails with connection_lost when connection process stops" do
      assert {:error, :connection_lost} ==
               request_failing_with(:connection_process_went_down)

      with_mock Finch, [:passthrough],
        request: fn _, _, _ -> exit(:killed) end do
        assert {:error, :connection_lost} == request()
      end
    end

    test "can be retried when connection process is not running" do
      not_running = fn _, _, _ -> exit({:noproc, {:gen_statem, :call, []}}) end

      with_mock Finch, [:passthrough], request: not_running do
        assert {:retry, :disconnected} == request()
      end
    end

    defp request(timeout \\ 1_000) do
      H2Adapter.request(@conn, "/path", [{"header", "value"}], "body", timeout)
    end

    defp request_failing_with(reason) do
      error = {:error, %Finch.Error{reason: reason}}

      with_mock Finch, [:passthrough], request: fn _, _, _ -> error end do
        request()
      end
    end
  end

  describe "connection pool options" do
    setup do
      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
          {"authorization", "bearer token"}
        end)

      {:ok, config: %{domain: "localhost", port: 443, authentication: auth}}
    end

    test "ping interval is passed to finch", %{config: config} do
      config = Sparrow.H2Worker.Config.new(Map.put(config, :ping_interval, 123))
      assert 123 == default_pool_opts(config)[:http2][:ping_interval]
    end

    test "ping is sent every 5 seconds of inactivity by default", %{
      config: config
    } do
      config = Sparrow.H2Worker.Config.new(config)
      assert 5_000 == default_pool_opts(config)[:http2][:ping_interval]
    end

    test "number of connections is passed to finch", %{config: config} do
      config = Sparrow.H2Worker.Config.new(Map.put(config, :connections, 7))
      assert 7 == default_pool_opts(config)[:count]
      assert [:http2] == default_pool_opts(config)[:protocols]
    end

    test "ping is switched off with nil interval", %{config: config} do
      config = Sparrow.H2Worker.Config.new(Map.put(config, :ping_interval, nil))
      assert :infinity == default_pool_opts(config)[:http2][:ping_interval]
    end

    defp default_pool_opts(config) do
      [%{start: {Finch, :start_link, [opts]}} | _] =
        H2Adapter.child_specs(config)

      opts[:pools][:default]
    end
  end
end
