defmodule Sparrow.Pool.RequestTest do
  use ExUnit.Case

  import Mock

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.Pool.Connections
  alias Sparrow.Authentication.CertificateBased
  alias Sparrow.Authentication.TokenBased
  alias Sparrow.Pool.Config
  alias Sparrow.Request

  @connection_ref :connection_ref
  @headers [{"header", "value"}]
  @response {:ok, {[{":status", "200"}], "response body"}}

  # The pool is started without real connections
  defmacrop with_request(request_fun, do: block) do
    quote do
      with_mock Connections, [:passthrough],
        child_specs: fn _config -> [] end,
        open: fn _config -> {:ok, @connection_ref} end,
        request: unquote(request_fun) do
        unquote(block)
      end
    end
  end

  setup do
    config =
      Config.new(%{
        domain: "domain",
        port: 443,
        authentication: CertificateBased.new("cert.pem", "key.pem")
      })

    {:ok,
     config: config, request: Request.new(@headers, "body", "/path", 1_000)}
  end

  describe "request" do
    test "returns response", %{config: config, request: request} do
      with_request fn _, _, _, _, _ -> @response end do
        assert @response == send_request(config, request)

        assert called(
                 Connections.request(
                   @connection_ref,
                   "/path",
                   @headers,
                   "body",
                   :_
                 )
               )
      end
    end

    test "returns error", %{config: config, request: request} do
      with_request fn _, _, _, _, _ -> {:error, :reason} end do
        assert {:error, :reason} == send_request(config, request)
      end
    end

    test "is given the time it has left", %{config: config, request: request} do
      test_pid = self()

      send_timeout = fn _, _, _, _, timeout ->
        send(test_pid, {:timeout, timeout})
        @response
      end

      with_request send_timeout do
        send_request(config, request)

        assert_receive {:timeout, timeout}
        assert timeout <= 1_000
        assert timeout > 900
      end
    end

    test "returns error when sending raises", %{
      config: config,
      request: request
    } do
      with_request fn _, _, _, _, _ -> raise "error" end do
        assert {:error, {:error, %RuntimeError{message: "error"}}} ==
                 send_request(config, request)
      end
    end
  end

  describe "request which was not sent" do
    test "is sent again", %{config: config, request: request} do
      {:ok, attempts} = Agent.start_link(fn -> 0 end)

      second_attempt_succeeds = fn _, _, _, _, _ ->
        case Agent.get_and_update(attempts, &{&1, &1 + 1}) do
          0 -> {:retry, :pool_not_available}
          _ -> @response
        end
      end

      with_request second_attempt_succeeds do
        assert @response == send_request(config, request)
        assert 2 == Agent.get(attempts, & &1)
      end
    end

    test "fails with the last reason when its time is up", %{config: config} do
      request = Request.new(@headers, "body", "/path", 200)

      with_request fn _, _, _, _, _ -> {:retry, :pool_not_available} end do
        {time, response} = :timer.tc(fn -> send_request(config, request) end)

        assert {:error, :pool_not_available} == response
        assert time >= 150_000
        assert time < 1_000_000
      end
    end
  end

  describe "authentication" do
    test "token is added to headers", %{config: config, request: request} do
      auth = TokenBased.new(fn -> {"authorization", "bearer token"} end)
      config = %{config | authentication: auth}

      with_request fn _, _, _, _, _ -> @response end do
        send_request(config, request)

        assert called(
                 Connections.request(
                   @connection_ref,
                   "/path",
                   [{"authorization", "bearer token"} | @headers],
                   "body",
                   :_
                 )
               )
      end
    end

    test "request fails when token cannot be obtained", %{
      config: config,
      request: request
    } do
      auth = TokenBased.new(fn -> exit(:no_token) end)
      config = %{config | authentication: auth}

      with_request fn _, _, _, _, _ -> @response end do
        assert {:error, {:exit, :no_token}} == send_request(config, request)
        assert_not_called(Connections.request(:_, :_, :_, :_, :_))
      end
    end
  end

  describe "telemetry" do
    setup do
      Setup.forward_telemetry([:sparrow, :h2_worker, :handle])
      Setup.forward_telemetry([:sparrow, :h2_worker, :request_success])
      Setup.forward_telemetry([:sparrow, :h2_worker, :request_error])
    end

    test "successful request is reported with its time", %{
      config: config,
      request: request
    } do
      slow_response = fn _, _, _, _, _ ->
        Process.sleep(50)
        @response
      end

      with_request slow_response do
        send_request(config, request)

        assert_receive {[:sparrow, :h2_worker, :handle], %{time: time},
                        %{
                          domain: "domain",
                          port: 443,
                          pool_name: :pool,
                          pool_type: :fcm,
                          pool_tags: [:tag]
                        }}

        assert time >= 50_000

        assert_receive {[:sparrow, :h2_worker, :request_success], %{},
                        %{pool_name: :pool}}

        refute_receive {[:sparrow, :h2_worker, :request_error], _, _}, 50
      end
    end

    test "failed request is reported with its reason", %{
      config: config,
      request: request
    } do
      with_request fn _, _, _, _, _ -> {:error, :reason} end do
        send_request(config, request)

        assert_receive {[:sparrow, :h2_worker, :handle], %{time: _time}, _}

        assert_receive {[:sparrow, :h2_worker, :request_error], %{},
                        %{pool_name: :pool, return_code: :reason}}

        refute_receive {[:sparrow, :h2_worker, :request_success], _, _}, 50
      end
    end
  end

  defp send_request(config, request) do
    {:ok, _pid} =
      config
      |> Setup.start_pool(name: :pool, type: :fcm, tags: [:tag])

    Sparrow.Pool.send_request(:pool, request)
  end
end
