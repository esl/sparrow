defmodule Sparrow.Pool.ConfigTest do
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
        Sparrow.Authentication.CertificateBased.new(
          @path_to_cert,
          @path_to_key
        )

      config =
        Sparrow.Pool.Config.new(%{
          domain: domain,
          port: port,
          authentication: auth
        })

      assert :certificate_based ==
               Sparrow.Pool.Config.get_authentication_type(config)
    end
  end

  test "authentication type recognised correctly for token" do
    ptest [
            domain: string(min: 3, max: 15, chars: :ascii),
            port: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      auth =
        Sparrow.Authentication.TokenBased.new(fn -> "dummyToken" end)

      config =
        Sparrow.Pool.Config.new(%{
          domain: domain,
          port: port,
          authentication: auth
        })

      assert :token_based ==
               Sparrow.Pool.Config.get_authentication_type(config)
    end
  end

  test "connection TLS options contain certificate for certificate based authentication" do
    auth =
      Sparrow.Authentication.CertificateBased.new(
        "path/to/cert.pem",
        "path/to/key.pem"
      )

    config =
      Sparrow.Pool.Config.new(%{
        domain: "domain",
        port: 443,
        authentication: auth,
        tls_options: [verify: :verify_none]
      })

    assert [
             certfile: "path/to/cert.pem",
             keyfile: "path/to/key.pem",
             verify: :verify_none
           ] == Sparrow.Pool.Config.connection_tls_options(config)
  end

  test "connection TLS options are not changed for token based authentication" do
    auth =
      Sparrow.Authentication.TokenBased.new(fn ->
        {"authorization", "bearer token"}
      end)

    config =
      Sparrow.Pool.Config.new(%{
        domain: "domain",
        port: 443,
        authentication: auth,
        tls_options: [verify: :verify_none]
      })

    assert [verify: :verify_none] ==
             Sparrow.Pool.Config.connection_tls_options(config)
  end

  describe "defaults" do
    setup do
      auth = Sparrow.Authentication.TokenBased.new(fn -> "dummyToken" end)
      {:ok, params: %{domain: "domain", port: 443, authentication: auth}}
    end

    test "are set", %{params: params} do
      config = Sparrow.Pool.Config.new(params)

      assert nil == config.type
      assert [] == config.tags
      assert [] == config.tls_options
      assert 3 == config.connections
      assert 5_000 == config.ping_interval
    end

    test "name is generated when not given", %{params: params} do
      config1 = Sparrow.Pool.Config.new(params)
      config2 = Sparrow.Pool.Config.new(params)

      assert is_atom(config1.name)
      assert nil != config1.name
      assert config1.name != config2.name
    end

    test "given values are kept", %{params: params} do
      config =
        Sparrow.Pool.Config.new(
          Map.merge(params, %{
            name: :pool_name,
            type: {:apns, :dev},
            tags: [:tag],
            connections: 7,
            ping_interval: nil
          })
        )

      assert :pool_name == config.name
      assert {:apns, :dev} == config.type
      assert [:tag] == config.tags
      assert 7 == config.connections
      assert nil == config.ping_interval
    end

    test "unknown parameter is rejected", %{params: params} do
      assert_raise KeyError, fn ->
        Sparrow.Pool.Config.new(Map.put(params, :reconnect_attempts, 3))
      end
    end
  end

  test "pool info describes the pool" do
    auth = Sparrow.Authentication.TokenBased.new(fn -> "dummyToken" end)

    config =
      Sparrow.Pool.Config.new(%{
        name: :pool_name,
        type: :fcm,
        tags: [:tag],
        domain: "domain",
        port: 443,
        authentication: auth
      })

    assert %{
             domain: "domain",
             port: 443,
             pool_name: :pool_name,
             pool_type: :fcm,
             pool_tags: [:tag]
           } == Sparrow.Pool.Config.pool_info(config)
  end
end
