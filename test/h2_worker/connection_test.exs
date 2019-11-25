defmodule Sparrow.H2Worker.ConnectionTest do
  alias Helpers.SetupHelper, as: Tools
  use ExUnit.Case
  use Quixir

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Sparrow.H2Worker.Config
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias Sparrow.H2Worker.State

  @repeats 2

  setup do
    :set_mox_from_context
    :verify_on_exit!
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
      conn_pid = pid()
      me = self()

       Sparrow.H2ClientAdapter.Mock
       |> expect(:open, 1, fn _, _, _ -> (send(me, {:first_connection_failure, Time.utc_now}); {:error, reason}) end)
       |> expect(:open, 4, fn _, _, _ -> {:error, reason} end)
       |> expect(:open, 1, fn _, _, _ -> (send(me, {:first_connection_success, Time.utc_now}); {:ok, conn_pid}) end)
       |> stub(:ping, fn _ -> :ok end)
       |> stub(:post, fn _, _, _, _, _ -> {:error, :something} end)
       |> stub(:get_response, fn _, _ -> {:error, :something} end)
       |> stub(:close, fn _ -> :ok end)

       config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options
          })

       {:ok, _pid} = start_supervised(Tools.h2_worker_spec(config))

       assert_receive {:first_connection_failure, f}, 200
       assert_receive {:first_connection_success, s}, 2_000
       assert_in_delta 1800, 1900, Time.diff(s, f, :millisecond)
    end
  end

  test "reconnection attempts with backoffs after the connection is closed", context do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      conn_pid = pid()
      new_conn_pid = pid()
      me = self()

       Sparrow.H2ClientAdapter.Mock
       |> expect(:open, 1, fn _, _, _ -> (send(me, {:connection_success, Time.utc_now}); {:ok, conn_pid}) end)
       |> expect(:open, 1, fn _, _, _ -> (send(me, {:reconnection_failure, Time.utc_now}); {:error, reason}) end)
       |> expect(:open, 4, fn _, _, _ -> {:error, reason} end)
       |> expect(:open, 1, fn _, _, _ -> (send(me, {:reconnection_success, Time.utc_now}); {:ok, new_conn_pid}) end)
       |> stub(:ping, fn ref -> (send(self(), {:PONG, ref}); :ok) end)
       |> stub(:post, fn _, _, _, _, _ -> {:error, :something} end)
       |> stub(:get_response, fn _, _ -> {:error, :something} end)
       |> stub(:close, fn _ -> :ok end)

       config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options
          })

       {:ok, _pid} = start_supervised(Tools.h2_worker_spec(config))
       assert_receive {:connection_success, s}, 200
       Process.exit(conn_pid, :custom_reason)

       assert_receive {:reconnection_failure, f}, 200
       assert_receive {:reconnection_success, s}, 2_000
       assert_in_delta 1800, 1900, Time.diff(s, f, :millisecond)
    end
  end

  test "reconnection attempts with backoffs after the request is sent", context do
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
      conn_pid = pid()
      me = self()
      request_timeout = 300
      headers = List.zip([headersA, headersB])

       Sparrow.H2ClientAdapter.Mock
       |> expect(:open, 1, fn _, _, _ -> (send(me, :connection_failure); {:error, reason}) end)
       |> expect(:open, 3, fn _, _, _ -> {:error, reason} end)
       |> expect(:open, 1, fn _, _, _ -> (send(me, :connection_failure); {:error, reason}) end)
       |> expect(:open, 1, fn _, _, _ -> (send(me, :connection_success); {:ok, conn_pid}) end)
       |> stub(:ping, fn ref -> (send(self(), {:PONG, ref}); :ok) end)
       |> stub(:post, fn _, _, _, _, _ -> {:error, :unable_to_connect} end)
       |> stub(:get_response, fn _, _ -> {:error, :something} end)
       |> stub(:close, fn _ -> :ok end)

       config =
          Config.new(%{
            domain: domain,
            port: port,
            authentication: context[:auth],
            tls_options: tls_options,
            backoff_base: 200,
            backoff_initial_delay: 10,
            backoff_max_delay: 2_000
          })

       request = OuterRequest.new(headers, body, path, request_timeout)

       {:ok, pid} = start_supervised(Tools.h2_worker_spec(config))

       assert_receive :connection_failure, 100

       assert {:error, :unable_to_connect} ==
                 GenServer.call(pid, {:send_request, request})

       assert_receive :connection_failure, 100
       assert_receive :connection_success, 2_000
    end
  end

  defp pid do
    spawn(fn -> :timer.sleep(5_000) end)
  end
end
