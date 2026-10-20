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
        connection_ref: fn _config -> @connection_ref end,
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
        assert timeout > 500
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
      second_attempt_succeeds = [
        in_series(
          [:_, :_, :_, :_, :_],
          [{:retry, :pool_not_available}, @response]
        )
      ]

      with_request second_attempt_succeeds do
        assert @response == send_request(config, request)
        assert_called_exactly(Connections.request(:_, :_, :_, :_, :_), 2)
      end
    end

    test "fails with unable_to_connect when its time is up", %{config: config} do
      request = Request.new(@headers, "body", "/path", 200)

      with_request fn _, _, _, _, _ -> {:retry, :pool_not_available} end do
        {time, response} = :timer.tc(fn -> send_request(config, request) end)

        assert {:error, {:unable_to_connect, :pool_not_available}} == response
        assert time >= 150_000
        assert time < 5_000_000
      end
    end
  end

  describe "retried request" do
    setup do
      {:ok, attempts} = Agent.start_link(fn -> [] end)
      {:ok, attempts: attempts}
    end

    test "is not sent again when its time is up", %{config: config} do
      request = Request.new(@headers, "body", "/path", 100)

      slow_retry = fn _, _, _, _, _ ->
        Process.sleep(150)
        {:retry, :pool_not_available}
      end

      with_request slow_retry do
        assert {:error, {:unable_to_connect, :pool_not_available}} ==
                 send_request(config, request)

        assert_called_exactly(Connections.request(:_, :_, :_, :_, :_), 1)
      end
    end

    test "is sent again less and less often", %{
      config: config,
      attempts: attempts
    } do
      request = Request.new(@headers, "body", "/path", 600)

      with_request record_and_retry(attempts, :pool_not_available) do
        send_request(config, request)

        gaps = attempt_gaps(attempts)

        # 24 attempts if they were sent every 25ms
        assert length(gaps) in 3..6

        for {gap, delay} <- Enum.zip(gaps, [25, 50, 100, 200, 250, 250]) do
          assert gap >= delay
        end
      end
    end

    test "is sent again often when the server has no free streams", %{
      config: config,
      attempts: attempts
    } do
      request = Request.new(@headers, "body", "/path", 600)

      with_request record_and_retry(attempts, :too_many_concurrent_requests) do
        send_request(config, request)

        # 5 attempts if they were sent less and less often
        assert length(attempt_times(attempts)) >= 10
      end
    end
  end

  test "sync request fails with connection_lost when it's stopped", %{
    config: config,
    request: request
  } do
    test_pid = self()

    hanging = fn _, _, _, _, _ ->
      send(test_pid, {:sending, self()})
      Process.sleep(:infinity)
    end

    with_request hanging do
      {:ok, _pid} = Setup.start_pool(config, name: :pool, type: :fcm)
      caller = Task.async(fn -> Sparrow.Pool.send_request(:pool, request) end)

      assert_receive {:sending, pid}
      Process.exit(pid, :kill)

      assert {:error, :connection_lost} == Task.await(caller)
    end
  end

  test "request fails with too_many_concurrent_requests when there are no free streams",
       %{config: config} do
    request = Request.new(@headers, "body", "/path", 100)
    no_streams = fn _, _, _, _, _ -> {:retry, :too_many_concurrent_requests} end

    with_request no_streams do
      assert {:error, :too_many_concurrent_requests} ==
               send_request(config, request)
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
      Setup.forward_telemetry([:sparrow, :pool, :request])
      Setup.forward_telemetry([:sparrow, :pool, :retry])
    end

    test "successful request is reported with its time and status", %{
      config: config,
      request: request
    } do
      slow_response = fn _, _, _, _, _ ->
        Process.sleep(50)
        @response
      end

      with_request slow_response do
        send_request(config, request)

        assert_receive {[:sparrow, :pool, :request], %{time: time},
                        %{
                          domain: "domain",
                          port: 443,
                          pool_name: :pool,
                          pool_type: :fcm,
                          pool_tags: [:tag],
                          result: :ok,
                          reason: nil,
                          status: 200
                        }}

        assert time >= 50_000

        refute_receive {[:sparrow, :pool, :request], _, _}, 50
        refute_receive {[:sparrow, :pool, :retry], _, _}, 50
      end
    end

    test "failed request is reported with its reason", %{
      config: config,
      request: request
    } do
      with_request fn _, _, _, _, _ -> {:error, :reason} end do
        send_request(config, request)

        assert_receive {[:sparrow, :pool, :request], %{time: _time},
                        %{
                          pool_name: :pool,
                          result: :error,
                          reason: :reason,
                          status: nil
                        }}

        refute_receive {[:sparrow, :pool, :request], _, _}, 50
      end
    end

    test "request which had to be sent again is reported once", %{
      config: config
    } do
      request = Request.new(@headers, "body", "/path", 200)

      with_request fn _, _, _, _, _ -> {:retry, :pool_not_available} end do
        send_request(config, request)

        assert_receive {[:sparrow, :pool, :retry], %{},
                        %{
                          domain: "domain",
                          pool_name: :pool,
                          reason: :pool_not_available
                        }}

        # The request itself is reported when its time is up
        assert_receive {[:sparrow, :pool, :request], %{time: _time},
                        %{
                          result: :error,
                          reason: {:unable_to_connect, :pool_not_available}
                        }}

        refute_receive {[:sparrow, :pool, :request], _, _}, 50
        refute_receive {[:sparrow, :pool, :retry], _, _}, 50
      end
    end

    test "request which is not sent again is not reported as such", %{
      config: config
    } do
      request = Request.new(@headers, "body", "/path", 100)

      slow_retry = fn _, _, _, _, _ ->
        Process.sleep(150)
        {:retry, :pool_not_available}
      end

      with_request slow_retry do
        send_request(config, request)

        assert_receive {[:sparrow, :pool, :request], _, %{result: :error}}
        refute_receive {[:sparrow, :pool, :retry], _, _}, 50
      end
    end
  end

  defp send_request(config, request) do
    {:ok, _pid} =
      config
      |> Setup.start_pool(name: :pool, type: :fcm, tags: [:tag])

    Sparrow.Pool.send_request(:pool, request)
  end

  defp record_and_retry(attempts, reason) do
    fn _, _, _, _, _ ->
      record_attempt(attempts)
      {:retry, reason}
    end
  end

  defp record_attempt(attempts) do
    Agent.update(attempts, &[System.monotonic_time(:microsecond) | &1])
  end

  defp attempt_times(attempts),
    do: attempts |> Agent.get(& &1) |> Enum.reverse()

  # Milliseconds between the attempts
  defp attempt_gaps(attempts) do
    attempts
    |> attempt_times()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [earlier, later] -> div(later - earlier, 1_000) end)
  end
end
