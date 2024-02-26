defmodule Sparrow.H2Worker.ConnectionTest do
  alias Helpers.SetupHelper, as: Tools
  use ExUnit.Case
  use Quixir

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @repeats 2

  setup do
    auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        "path/to/exampleName.pem",
        "path/to/exampleKey.pem"
      )

    real_auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        "test/priv/certs/Certificates1.pem",
        "test/priv/certs/key.pem"
      )

    {:ok, connection_ref: pid(), auth: auth, real_auth: real_auth}
  end

  test "connection attempts with backoffs at server's startup", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      me = self()

      Sparrow.H2ClientAdapter.Mock
      |> expect(:open, 1, fn _, _, _ ->
        send(me, {:first_connection_failure, :os.system_time(:millisecond)})
        {:error, reason}
      end)
      |> expect(:open, 4, fn _, _, _ -> {:error, reason} end)
      |> expect(:open, 1, fn _, _, _ ->
        send(me, {:first_connection_success, :os.system_time(:millisecond)})
        {:ok, context[:connection_ref]}
      end)
      |> stub(:ping, fn _ -> :ok end)
      |> stub(:post, fn _, _, _, _, _ -> {:error, :something} end)
      |> stub(:get_response, fn _, _ -> {:error, :something} end)
      |> stub(:close, fn _ -> :ok end)

      config =
        Config.new(%{
          domain: domain,
          port: port,
          authentication: context[:auth],
          tls_options: tls_options,
          backoff_base: 2,
          backoff_initial_delay: 100,
          backoff_max_delay: 400
        })

      {:ok, _pid} = start_supervised(Tools.h2_worker_spec(config))

      assert_receive {:first_connection_failure, _f}, 200
      assert_receive {:first_connection_success, _s}, 2_000

      # FIXME: global mock is making this test flaky,
      #  i.e. if some other process calls mock.open/3
      #  then the whole backoff time is shorter than expected
      # assert_in_delta f, s, 1900
      # refute_in_delta f, s, 1800
    end
  end

  test "reconnection attempts with backoffs after the connection is closed",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      conn_pid = pid()
      me = self()

      Sparrow.H2ClientAdapter.Mock
      |> expect(:open, 1, fn _, _, _ ->
        send(me, {:connection_success, :os.system_time(:millisecond)})
        {:ok, conn_pid}
      end)
      |> expect(:open, 1, fn _, _, _ ->
        send(me, {:reconnection_failure, :os.system_time(:millisecond)})
        {:error, reason}
      end)
      |> expect(:open, 4, fn _, _, _ -> {:error, reason} end)
      |> expect(:open, 1, fn _, _, _ ->
        send(me, {:reconnection_success, :os.system_time(:millisecond)})
        {:ok, context[:connection_ref]}
      end)
      |> stub(:ping, fn ref ->
        send(self(), {:PONG, ref})
        :ok
      end)
      |> stub(:post, fn _, _, _, _, _ -> {:error, :something} end)
      |> stub(:get_response, fn _, _ -> {:error, :something} end)
      |> stub(:close, fn _ -> :ok end)

      config =
        Config.new(%{
          domain: domain,
          port: port,
          authentication: context[:auth],
          tls_options: tls_options,
          backoff_base: 2,
          backoff_initial_delay: 100,
          backoff_max_delay: 400
        })

      {:ok, _pid} = start_supervised(Tools.h2_worker_spec(config))
      assert_receive {:connection_success, _s}, 200
      send(conn_pid, :exit)

      assert_receive {:reconnection_failure, _f}, 200
      assert_receive {:reconnection_success, _s}, 2_000

      # FIXME: global mock is making this test flaky,
      #  i.e. if some other process calls mock.open/3
      #  then the whole backoff time is shorter than expected
      # assert_in_delta f, s, 1900
      # refute_in_delta f, s, 1800
    end
  end

  test "reconnection attempts with backoffs after the request is sent",
       context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 7, chars: :ascii),
            path: string(min: 3, max: 7, chars: :ascii)
          ],
          repeat_for: @repeats do
      me = self()
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      Sparrow.H2ClientAdapter.Mock
      |> expect(:open, 1, fn _, _, _ ->
        send(me, :connection_failure)
        {:error, reason}
      end)
      |> expect(:open, 3, fn _, _, _ -> {:error, reason} end)
      |> expect(:open, 1, fn _, _, _ ->
        send(me, :connection_failure)
        {:error, reason}
      end)
      |> expect(:open, 1, fn _, _, _ ->
        send(me, :connection_success)
        {:ok, context[:connection_ref]}
      end)
      |> stub(:ping, fn ref ->
        send(self(), {:PONG, ref})
        :ok
      end)
      |> stub(:post, fn _, _, _, _, _ ->
        {:error, {:unable_to_connect, :some_reason}}
      end)
      |> stub(:get_response, fn _, _ -> {:error, :something} end)
      |> stub(:close, fn _ -> :ok end)

      config =
        Config.new(%{
          domain: domain,
          port: port,
          authentication: context[:auth],
          tls_options: tls_options,
          backoff_base: 2,
          backoff_initial_delay: 2_000,
          backoff_max_delay: 2_000
        })

      request = OuterRequest.new(headers, body, path, request_timeout)

      {:ok, pid} = start_supervised(Tools.h2_worker_spec(config))

      assert_receive :connection_failure, 100

      assert {:error, {:unable_to_connect, _}} =
               GenServer.call(pid, {:send_request, request})

      assert_receive :connection_failure, 2_000
      assert_receive :connection_success, 5_000
    end
  end

  defp pid do
    spawn(fn -> do_nothing() end)
  end

  defp do_nothing do
    receive do
      :exit -> exit(:reason)
    end
  end
end
