defmodule Helpers.SetupHelper do
  @moduledoc false

  import Mox

  alias Sparrow.H2Worker.Config

  @path_to_cert "priv/ssl/client_cert.pem"
  @path_to_key "priv/ssl/client_key.pem"

  def passthrough_h2(state) do
    Sparrow.H2ClientAdapter.Mock
    |> stub_with(Sparrow.H2ClientAdapter.Finch)

    state
  end

  @doc """
  Starts a pool which is stopped before the next test starts, so its name
  can be used again.
  """
  def start_pool(pool_config, pool_type, tags \\ []) do
    ExUnit.Callbacks.start_supervised(%{
      id: {Sparrow.H2Worker.Pool, pool_config.pool_name},
      start:
        {Sparrow.H2Worker.Pool, :start_unregistered,
         [pool_config, pool_type, tags]},
      type: :supervisor
    })
  end

  @doc """
  Starts processes needed by connections of a worker started without a pool.
  """
  def start_connection_processes(config) do
    for spec <- Sparrow.H2ClientAdapter.Finch.child_specs(config) do
      case ExUnit.Callbacks.start_supervised(spec) do
        # `:undefined` for the spec which only attaches the telemetry handler
        {:ok, _pid_or_undefined} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, {{:already_started, _pid}, _spec}} -> :ok
      end
    end

    :ok
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
