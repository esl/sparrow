defmodule H2Worker.ConfigTest do
  use ExUnit.Case
  use Quixir

  @path_to_cert "test/priv/certs/Certificates1.pem"
  @path_to_key "test/priv/certs/key.pem"

  @repeats 10

  test "authentication type recognised correctly, for certificate" do
    ptest [
            domain: string(min: 3, max: 15, chars: :ascii),
            port: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      auth =
        Sparrow.H2Worker.Authentication.CertificateBased.new(
          @path_to_cert,
          @path_to_key
        )

      config =
        Sparrow.H2Worker.Config.new(%{
          domain: domain,
          port: port,
          authentication: auth
        })

      assert :certificate_based ==
               Sparrow.H2Worker.Config.get_authentication_type(config)
    end
  end

  test "authentication type recognised correctly for token" do
    ptest [
            domain: string(min: 3, max: 15, chars: :ascii),
            port: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn -> "dummyToken" end)

      config =
        Sparrow.H2Worker.Config.new(%{
          domain: domain,
          port: port,
          authentication: auth
        })

      assert :token_based ==
               Sparrow.H2Worker.Config.get_authentication_type(config)
    end
  end

  test "connection TLS options contain certificate for certificate based authentication" do
    auth =
      Sparrow.H2Worker.Authentication.CertificateBased.new(
        "path/to/cert.pem",
        "path/to/key.pem"
      )

    config =
      Sparrow.H2Worker.Config.new(%{
        domain: "domain",
        port: 443,
        authentication: auth,
        tls_options: [verify: :verify_none]
      })

    assert [
             certfile: "path/to/cert.pem",
             keyfile: "path/to/key.pem",
             verify: :verify_none
           ] == Sparrow.H2Worker.Config.connection_tls_options(config)
  end

  test "connection TLS options are not changed for token based authentication" do
    auth =
      Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
        {"authorization", "bearer token"}
      end)

    config =
      Sparrow.H2Worker.Config.new(%{
        domain: "domain",
        port: 443,
        authentication: auth,
        tls_options: [verify: :verify_none]
      })

    assert [verify: :verify_none] ==
             Sparrow.H2Worker.Config.connection_tls_options(config)
  end
end
