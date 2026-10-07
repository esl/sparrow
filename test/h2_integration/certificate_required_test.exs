defmodule H2Integration.CerificateRequiredTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @cert_path "priv/ssl/client_cert.pem"
  @key_path "priv/ssl/client_key.pem"

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/EchoClientCerificateHandler",
            Helpers.CowboyHandlers.EchoClientCerificateHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(
        certificate_required: :positive_cerificate_verification
      )

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  @pool_name :pool
  test "cowboy replies with sent cerificate", context do
    auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        @cert_path,
        @key_path
      )

    config =
      Sparrow.H2Worker.Config.new(%{
        domain: Setup.server_host(),
        port: context[:port],
        authentication: auth,
        tls_options: [verify: :verify_none]
      })

    headers = Setup.default_headers()
    body = "body"

    request =
      OuterRequest.new(headers, body, "/EchoClientCerificateHandler", 2_000)

    Sparrow.H2Worker.Pool.Config.new(config, @pool_name)
    |> Sparrow.H2Worker.Pool.start_unregistered(:fcm, [])

    {:ok, {answer_headers, answer_body}} =
      Sparrow.H2Worker.Pool.send_request(@pool_name, request)

    {:ok, pem_bin} = File.read(@cert_path)

    expected_subject =
      Helpers.CerificateHelper.get_subject_name_form_not_encoded_cert(pem_bin)

    assert_response_header(answer_headers, {":status", "200"})
    assert expected_subject == answer_body
  end

  test "worker rejects cowboy cerificate", context do
    auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        @cert_path,
        @key_path
      )

    config =
      Sparrow.H2Worker.Config.new(%{
        domain: Setup.server_host(),
        port: context[:port],
        authentication: auth,
        tls_options: [
          {:verify, :verify_peer}
        ],
        ping_interval: 10_000
      })

    request =
      OuterRequest.new(
        Setup.default_headers(),
        "body",
        "/OkResponseHandler",
        500
      )

    Setup.forward_telemetry([:sparrow, :h2_worker, :conn_fail])
    :ok = Setup.start_connection_processes(config)
    worker_pid = start_supervised!(Setup.h2_worker_spec(config))

    # No CA certificates are given, so the default ones are used and the
    # self-signed certificate of the server is not trusted
    assert_receive {[:sparrow, :h2_worker, :conn_fail], _measurements,
                    %{reason: {:tls_alert, {:bad_certificate, _}}}},
                   2_000

    refute Sparrow.H2Worker.alive_connection?(worker_pid)

    assert {:error, :pool_not_available} ==
             GenServer.call(worker_pid, {:send_request, request})
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
