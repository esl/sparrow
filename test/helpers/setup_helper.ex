defmodule Helpers.SetupHelper do
  @moduledoc false

  import Mox

  alias Sparrow.H2Worker.Config

  @path_to_cert "priv/ssl/client_cert.pem"
  @path_to_key "priv/ssl/client_key.pem"

  def passthrough_h2(state) do
    Sparrow.H2ClientAdapter.Mock
    |> stub_with(Sparrow.H2ClientAdapter.Chatterbox)

    state
  end

  def h2_worker_spec(config) do
    id = :crypto.strong_rand_bytes(8) |> Base.encode64()
    Process.put(:id, id)

    Supervisor.child_spec({Sparrow.H2Worker, config}, id: id)
  end

  def child_spec(opts) do
    args = opts[:args]
    name = opts[:name]

    id = :rand.uniform(100_000)

    %{
      :id => id,
      :start => {Sparrow.H2Worker, :start_link, [name, args]}
    }
  end

  def cowboys_name do
    :look
  end

  def create_h2_worker_config(
        address \\ server_host(),
        port \\ 8080,
        authentication \\ :certificate_based
      ) do
    auth =
      case authentication do
        :token_based ->
          Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
            {"authorization", "bearer dummy_token"}
          end)

        :certificate_based ->
          Sparrow.H2Worker.Authentication.CertificateBased.new(
            @path_to_cert,
            @path_to_key
          )
      end

    Config.new(%{
      domain: address,
      port: port,
      authentication: auth,
      backoff_base: 2,
      backoff_initial_delay: 100,
      backoff_max_delay: 400,
      reconnect_attempts: 0,
      tls_options: [verify: :verify_none]
    })
  end

  defp certificate_settings_list do
    [
      {:cacertfile, "priv/ssl/fake_cert.pem"},
      {:certfile, "priv/ssl/fake_cert.pem"},
      {:keyfile, "priv/ssl/fake_key.pem"}
    ]
  end

  defp settings_list(:positive_cerificate_verification, port) do
    [
      {:port, port},
      {:verify, :verify_peer},
      {:verify_fun, {fn _, _, _ -> {:valid, :ok} end, :ok}}
      | certificate_settings_list()
    ]
  end

  defp settings_list(:negative_cerificate_verification, port) do
    [
      {:port, port},
      {:verify, :verify_peer},
      {:verify_fun,
       {fn _, _, _ -> {:fail, :negative_cerificate_verification} end, :ok}}
      | certificate_settings_list()
    ]
  end

  defp settings_list(:no, port) do
    [
      {:port, port}
      | certificate_settings_list()
    ]
  end

  def start_cowboy_tls(dispatch_config, opts) do
    cert_required = Keyword.get(opts, :certificate_required, :no)
    port = Keyword.get(opts, :port, 0)
    name = Keyword.get(opts, :name, :look)
    settings_list = settings_list(cert_required, port)

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
      {"user-agent", "chatterbox-client/0.0.1"}
    ]
  end
end
