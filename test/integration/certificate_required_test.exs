defmodule Integration.CertificateRequiredTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.Request

  @cert_path "priv/ssl/client_cert.pem"
  @key_path "priv/ssl/client_key.pem"

  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/EchoClientCertificateHandler",
            Helpers.CowboyHandlers.EchoClientCertificateHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(
        certificate_required: :positive_certificate_verification
      )

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  @pool_name :pool
  test "cowboy replies with sent certificate", context do
    auth =
      Sparrow.Authentication.CertificateBased.new(
        @cert_path,
        @key_path
      )

    config =
      Sparrow.Pool.Config.new(%{
        domain: Setup.server_host(),
        port: context[:port],
        authentication: auth,
        tls_options: [verify: :verify_none]
      })

    headers = Setup.default_headers()
    body = "body"

    request =
      Request.new(headers, body, "/EchoClientCertificateHandler", 2_000)

    Setup.start_pool(config, name: @pool_name, type: :fcm)

    {:ok, {answer_headers, answer_body}} =
      Sparrow.Pool.send_request(@pool_name, request)

    {:ok, pem_bin} = File.read(@cert_path)

    expected_subject =
      Helpers.CertificateHelper.get_subject_name_from_not_encoded_cert(pem_bin)

    assert_response_header(answer_headers, {":status", "200"})
    assert expected_subject == answer_body
  end

  test "worker rejects cowboy certificate", context do
    auth =
      Sparrow.Authentication.CertificateBased.new(
        @cert_path,
        @key_path
      )

    config =
      Sparrow.Pool.Config.new(%{
        domain: Setup.server_host(),
        port: context[:port],
        authentication: auth,
        tls_options: [
          {:verify, :verify_peer}
        ],
        ping_interval: 10_000
      })

    request =
      Request.new(
        Setup.default_headers(),
        "body",
        "/OkResponseHandler",
        500
      )

    Setup.forward_telemetry([:sparrow, :pool, :connect])
    pool = Setup.start_pool_with_config(config)

    # No CA certificates are given, so the default ones are used and the
    # self-signed certificate of the server is not trusted
    assert_receive {[:sparrow, :pool, :connect], _measurements,
                    %{
                      result: :error,
                      reason: {:tls_alert, {:bad_certificate, _}}
                    }},
                   2_000

    assert %{connected: 0} = Sparrow.Pool.stats(pool)

    assert {:error, {:unable_to_connect, :pool_not_available}} ==
             Sparrow.Pool.send_request(pool, request)
  end

  defp assert_response_header(headers, expected_header) do
    assert Enum.any?(headers, &(&1 == expected_header))
  end
end
