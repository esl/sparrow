defmodule Sparrow.Pool.ConnectionsTest do
  use ExUnit.Case

  alias Sparrow.Pool.Connections

  import Mock

  @conn %{
    finch: Sparrow.Finch.Pool,
    pool: Finch.Pool.new("https://localhost:443"),
    base_url: "https://localhost:443",
    strategy: {Finch.Pool.Strategy.RoundRobin, :counter}
  }

  describe "request" do
    setup do
      # Finch registers established connections of the pool like that
      start_supervised!({Registry, keys: :duplicate, name: @conn.finch})

      {:ok, _pid} =
        Registry.register(@conn.finch, Finch.Pool.to_name(@conn.pool), nil)

      :ok
    end

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

    test "fails with other reasons as they are" do
      assert {:error, :reason} == request_failing_with(:reason)
    end

    test "fails with request_timeout when response is not received in time" do
      assert {:error, :request_timeout} == request_failing_with(:timeout)
    end

    test "fails with connection_lost when connection is lost after sending" do
      for reason <- [:closed, :connection_closed, :connection_process_went_down] do
        assert {:error, :connection_lost} == request_failing_with(reason)
      end

      with_mock Finch, [:passthrough],
        request: fn _, _, _ -> exit(:killed) end do
        assert {:error, :connection_lost} == request()
      end
    end

    test "is not sent and can be retried when there are no connections" do
      :ok = Registry.unregister(@conn.finch, Finch.Pool.to_name(@conn.pool))

      with_mock Finch.Pool.Manager, [:passthrough],
        get_pool_mod: fn _, _ -> {:name, Finch.HTTP2.Pool} end do
        with_mock Finch, [:passthrough],
          request: fn _, _, _ -> exit(:sent) end do
          assert {:retry, :pool_not_available} == request()

          assert called(
                   Finch.Pool.Manager.get_pool_mod(@conn.finch, @conn.pool)
                 )
        end
      end
    end

    test "is sent when connections need to be started" do
      :ok = Registry.unregister(@conn.finch, Finch.Pool.to_name(@conn.pool))
      response = %Finch.Response{status: 200, headers: [], body: ""}

      with_mock Finch.Pool.Manager, [:passthrough],
        get_pool_mod: fn _, _ -> :not_found end do
        with_mock Finch, [:passthrough],
          request: fn _, _, _ -> {:ok, response} end do
          assert {:ok, {[{":status", "200"}], ""}} == request()
        end
      end
    end

    test "can be retried when connection process is not running" do
      not_running = fn _, _, _ -> exit({:noproc, {:gen_statem, :call, []}}) end

      with_mock Finch, [:passthrough], request: not_running do
        assert {:retry, :disconnected} == request()
      end
    end

    defp request(timeout \\ 1_000) do
      Connections.request(
        @conn,
        "/path",
        [{"header", "value"}],
        "body",
        timeout
      )
    end

    defp request_failing_with(reason) do
      error = {:error, %Finch.Error{reason: reason}}

      with_mock Finch, [:passthrough], request: fn _, _, _ -> error end do
        request()
      end
    end
  end

  describe "telemetry handler" do
    setup do
      config =
        Helpers.SetupHelper.create_pool_config("localhost", 1, :token_based)

      {:ok,
       config: config, handler_id: {Connections, Connections.finch_name(config)}}
    end

    test "is attached as long as the pool is running", context do
      {:ok, _pid} = Helpers.SetupHelper.start_pool(context.config)
      assert context.handler_id in handler_ids()

      :ok = stop_supervised({Sparrow.Pool, context.config.name})
      refute context.handler_id in handler_ids()
    end

    defp handler_ids do
      for handler <- :telemetry.list_handlers([:finch, :connect, :stop]) do
        handler.id
      end
    end
  end

  describe "connection pool options" do
    setup do
      auth =
        Sparrow.Authentication.TokenBased.new(fn ->
          {"authorization", "bearer token"}
        end)

      {:ok, config: %{domain: "localhost", port: 443, authentication: auth}}
    end

    test "ping interval is passed to finch", %{config: config} do
      config = Sparrow.Pool.Config.new(Map.put(config, :ping_interval, 123))
      assert 123 == default_pool_opts(config)[:http2][:ping_interval]
    end

    test "ping is sent every 5 seconds of inactivity by default", %{
      config: config
    } do
      config = Sparrow.Pool.Config.new(config)
      assert 5_000 == default_pool_opts(config)[:http2][:ping_interval]
    end

    test "number of connections is passed to finch", %{config: config} do
      config = Sparrow.Pool.Config.new(Map.put(config, :connections, 7))
      assert 7 == default_pool_opts(config)[:count]
      assert [:http2] == default_pool_opts(config)[:protocols]
    end

    test "ping is switched off with nil interval", %{config: config} do
      config = Sparrow.Pool.Config.new(Map.put(config, :ping_interval, nil))
      assert :infinity == default_pool_opts(config)[:http2][:ping_interval]
    end

    defp default_pool_opts(config) do
      [%{start: {Finch, :start_link, [opts]}} | _] =
        Connections.child_specs(config)

      opts[:pools][:default]
    end
  end
end
