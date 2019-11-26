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
end
