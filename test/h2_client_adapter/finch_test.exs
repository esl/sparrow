defmodule H2ClientAdapter.FinchTest do
  use ExUnit.Case

  alias Sparrow.H2ClientAdapter.Finch, as: H2Adapter

  @conn %{pool: nil, pid: nil, base_url: "https://localhost:443"}

  setup do
    {:ok, ref: {Finch.HTTP2.Pool, {self(), make_ref()}}}
  end

  test "response parts are translated", %{ref: ref} do
    assert {:response_part, ref, {:status, 200}} ==
             H2Adapter.handle_message({ref, {:status, 200}}, @conn)

    assert {:response_part, ref, {:headers, [{"apns-id", "1"}]}} ==
             H2Adapter.handle_message(
               {ref, {:headers, [{"apns-id", "1"}]}},
               @conn
             )

    assert {:response_part, ref, {:data, "body"}} ==
             H2Adapter.handle_message({ref, {:data, "body"}}, @conn)
  end

  test "end of response is translated", %{ref: ref} do
    assert {:done, ref} == H2Adapter.handle_message({ref, :done}, @conn)
  end

  test "error is translated to its reason", %{ref: ref} do
    error = %Finch.Error{reason: :connection_closed}

    assert {:error, ref, :connection_closed} ==
             H2Adapter.handle_message({ref, {:error, error}}, @conn)
  end

  test "messages not sent by finch are unknown" do
    assert :unknown == H2Adapter.handle_message({:ping, make_ref()}, @conn)
    assert :unknown == H2Adapter.handle_message({make_ref(), :done}, @conn)
    assert :unknown == H2Adapter.handle_message("message", @conn)
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
