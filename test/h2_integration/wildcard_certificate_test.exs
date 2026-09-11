defmodule H2Integration.WildcardCertificateTest do
  @moduledoc """
  Regression tests for wildcard certificate support in the pool supervisors'
  default TLS options.
  """
  use ExUnit.Case, async: false

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  import Mox
  setup :set_mox_global

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  @client_cert "priv/ssl/client_cert.pem"
  @client_key "priv/ssl/client_key.pem"

  # Covered by the wildcard SAN "DNS:*.sparrow.test" and nothing else, so it
  # only resolves against the certificate if wildcard matching is enabled.
  @wildcard_cert "priv/ssl/wildcard_cert.pem"
  @wildcard_key "priv/ssl/wildcard_key.pem"
  @wildcard_ca_cert "priv/ssl/wildcard_ca_cert.pem"
  @wildcard_host ~c"pool.sparrow.test"

  @fcm_service_account "sparrow_token.json"
  @pool_name :wildcard_cert_pool

  setup do
    :ok = :ssl.start()
    # Not configured in the test env, but FCM's `init/1` registers project ids.
    start_supervised!(Sparrow.FCM.V1.ProjectIdBearer)
    :ok
  end

  setup_all do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [{"/OkResponseHandler", Helpers.CowboyHandlers.OkResponseHandler, []}]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(
        certificate_required: :no,
        certfile: @wildcard_cert,
        keyfile: @wildcard_key,
        name: :wildcard_cert_listener
      )

    on_exit(fn -> :cowboy.stop_listener(cowboys_name) end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  describe "default TLS options" do
    test "FCM pool enables wildcard hostname matching" do
      assert Keyword.has_key?(
               fcm_default_tls_options(),
               :customize_hostname_check
             )
    end

    test "APNS pool enables wildcard hostname matching" do
      assert Keyword.has_key?(
               apns_default_tls_options(),
               :customize_hostname_check
             )
    end

    test "peer verification stays enabled" do
      for tls_options <- [fcm_default_tls_options(), apns_default_tls_options()] do
        assert Keyword.fetch!(tls_options, :verify) == :verify_peer
      end
    end
  end

  describe "handshake against a wildcard-only certificate" do
    test "FCM defaults accept it", %{port: port} do
      assert :ok == connect(port, fcm_default_tls_options())
    end

    test "APNS defaults accept it", %{port: port} do
      assert :ok == connect(port, apns_default_tls_options())
    end

    # Guards the tests above: without the option the handshake must fail, and
    # fail specifically on the hostname check rather than on path validation.
    test "it is rejected without customize_hostname_check", %{port: port} do
      tls_options =
        Keyword.delete(fcm_default_tls_options(), :customize_hostname_check)

      assert {:error, {:tls_alert, {_alert, reason}}} =
               connect(port, tls_options)

      assert to_string(reason) =~ "hostname_check_failed"
    end

    # The handshake tests above drive `:ssl` directly. This one goes through a
    # real pool, so it also covers the tls_opts reaching `:ssl.connect`
    # unchanged through the H2 client.
    test "an FCM pool serves a request over it", %{port: port} do
      config =
        Sparrow.H2Worker.Config.new(%{
          domain: Setup.server_host(),
          port: port,
          authentication:
            Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
              {"authorization", "bearer dummy_token"}
            end),
          tls_options: client_options(fcm_default_tls_options())
        })

      config
      |> Sparrow.H2Worker.Pool.Config.new(@pool_name)
      |> Sparrow.H2Worker.Pool.start_unregistered(:fcm, [])

      request =
        OuterRequest.new(
          Setup.default_headers(),
          "",
          "/OkResponseHandler",
          2_000
        )

      assert {:ok, {headers, _body}} =
               Sparrow.H2Worker.Pool.send_request(@pool_name, request)

      assert Enum.member?(headers, {":status", "200"})
    end
  end

  defp fcm_default_tls_options do
    [[path_to_json: @fcm_service_account]]
    |> Sparrow.FCM.V1.Pool.Supervisor.init()
    |> tls_options_from_init()
  end

  defp apns_default_tls_options do
    [
      dev: [
        [auth_type: :certificate_based, cert: @client_cert, key: @client_key]
      ]
    ]
    |> Sparrow.APNS.Pool.Supervisor.init()
    |> tls_options_from_init()
  end

  # The supervisors build their pool configs in `init/1`, so the defaults are
  # read back off the child spec rather than duplicated here.
  defp tls_options_from_init({:ok, {_sup_flags, children}}) do
    [%{start: {Sparrow.H2Worker.Pool, :start_link, [pool_config | _]}}] =
      children

    pool_config.workers_config.tls_options
  end

  # Overrides only the trust anchor and the reference hostname; the rest is as
  # the supervisors built it. `:cacerts` must be deleted, not overridden — while
  # it is set `:ssl` silently ignores `:cacertfile`. SNI is the identity the
  # certificate is checked against, so it is what puts the wildcard under test.
  defp client_options(tls_options) do
    tls_options
    |> Keyword.delete(:cacerts)
    |> Keyword.put(:cacertfile, @wildcard_ca_cert)
    |> Keyword.put(:server_name_indication, @wildcard_host)
  end

  defp connect(port, tls_options) do
    case :ssl.connect(~c"localhost", port, client_options(tls_options), 5_000) do
      {:ok, socket} -> :ssl.close(socket)
      {:error, reason} -> {:error, reason}
    end
  end
end
