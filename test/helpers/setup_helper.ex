defmodule Helpers.SetupHelper do
  alias Sparrow.H2Worker.Config
  alias Helpers.SetupHelper, as: Setup

  def child_spec(opts) do
    args = opts[:args]
    name = opts[:name]

    id = :rand.uniform(100_000)

    %{
      :id => id,
      :start => {Sparrow.H2Worker, :start_link, [name, args]}
    }
  end

  def cowboys_name() do
    :look
  end

  defp current_dir() do
    System.cwd()
  end

  def create_h2_worker_config(
        address \\ Setup.server_host(),
        port \\ 8080,
        args \\ [],
        timeout \\ 10_000
      ) do
    Config.new(address, port, args, timeout)
  end

  defp certificate_settings_list() do
    [
      {:cacertfile, current_dir() <> "/priv/ssl/fake_cert.pem"},
      {:certfile, current_dir() <> "/priv/ssl/fake_cert.pem"},
      {:keyfile, current_dir() <> "/priv/ssl/fake_key.pem"}
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
      {:verify_fun, {fn _, _, _ -> {:fail, :negative_cerificate_verification} end, :ok}}
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

  def server_host() do
    "localhost"
  end

  def default_headers() do
    [
      {"accept", "*/*"},
      {"accept-encoding", "gzip, deflate"},
      {"user-agent", "chatterbox-client/0.0.1"}
    ]
  end
end
