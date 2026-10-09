defmodule Helpers.SetupHelper do
  @moduledoc false

  alias Sparrow.Pool.Config

  @path_to_cert "priv/ssl/client_cert.pem"
  @path_to_key "priv/ssl/client_key.pem"

  @doc """
  Starts a pool with given config, updated with `fields`. The pool is stopped
  before the next test starts, so its name can be used again.
  """
  def start_pool(config, fields \\ []) do
    config = struct!(config, fields)

    ExUnit.Callbacks.start_supervised(%{
      id: {Sparrow.Pool, config.name},
      start: {Sparrow.Pool, :start_link, [config]},
      type: :supervisor
    })
  end

  @doc """
  Starts a pool with a unique name and given config, returns the name.
  """
  def start_pool_with_config(config, connections \\ 1) do
    name = :"pool_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_pool(config, name: name, connections: connections)
    name
  end

  @doc """
  Sends `{event, measurements, metadata}` to the calling process each time
  given telemetry event is executed.
  """
  def forward_telemetry(event) do
    test_pid = self()
    handler_id = {:forward_telemetry, test_pid, event}

    :ok =
      :telemetry.attach(
        handler_id,
        event,
        fn event, measurements, metadata, _config ->
          send(test_pid, {event, measurements, metadata})
        end,
        nil
      )

    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  def cowboys_name do
    :look
  end

  def create_pool_config(
        address \\ server_host(),
        port \\ 8080,
        authentication \\ :certificate_based
      ) do
    auth =
      case authentication do
        :token_based ->
          Sparrow.Authentication.TokenBased.new(fn ->
            {"authorization", "bearer dummy_token"}
          end)

        :certificate_based ->
          Sparrow.Authentication.CertificateBased.new(
            @path_to_cert,
            @path_to_key
          )
      end

    Config.new(%{
      domain: address,
      port: port,
      authentication: auth,
      tls_options: [verify: :verify_none]
    })
  end

  # `certfile`/`keyfile` let a test serve its own certificate; the defaults are
  # the generic ones from `mix sparrow.certs.dev`.
  defp certificate_settings_list(opts) do
    certfile = Keyword.get(opts, :certfile, "priv/ssl/fake_cert.pem")

    [
      {:cacertfile, Keyword.get(opts, :cacertfile, certfile)},
      {:certfile, certfile},
      {:keyfile, Keyword.get(opts, :keyfile, "priv/ssl/fake_key.pem")}
    ]
  end

  defp settings_list(:positive_cerificate_verification, port, opts) do
    [
      {:port, port},
      {:verify, :verify_peer},
      {:verify_fun, {fn _, _, _ -> {:valid, :ok} end, :ok}}
      | certificate_settings_list(opts)
    ]
  end

  defp settings_list(:negative_cerificate_verification, port, opts) do
    [
      {:port, port},
      {:verify, :verify_peer},
      {:verify_fun,
       {fn _, _, _ -> {:fail, :negative_cerificate_verification} end, :ok}}
      | certificate_settings_list(opts)
    ]
  end

  defp settings_list(:no, port, opts) do
    [
      {:port, port}
      | certificate_settings_list(opts)
    ]
  end

  def start_cowboy_tls(dispatch_config, opts) do
    cert_required = Keyword.get(opts, :certificate_required, :no)
    port = Keyword.get(opts, :port, 0)
    name = Keyword.get(opts, :name, :look)
    settings_list = settings_list(cert_required, port, opts)

    {:ok, pid} =
      :cowboy.start_tls(
        name,
        settings_list,
        %{:env => %{:dispatch => dispatch_config}}
      )

    {:ok, pid, name}
  end

  def server_host do
    "localhost"
  end

  def default_headers do
    [
      {"accept", "*/*"},
      {"accept-encoding", "gzip, deflate"},
      {"user-agent", "sparrow-client/0.0.1"}
    ]
  end
end
