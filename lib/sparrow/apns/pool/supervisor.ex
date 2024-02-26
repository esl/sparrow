defmodule Sparrow.APNS.Pool.Supervisor do
  @moduledoc """
  Supervises a single APNS workers pool.
  """
  use Supervisor

  @apns_dev_endpoint "api.development.push.apple.com"
  @apns_prod_endpoint "api.push.apple.com"
  @apns_endpoint [{:dev, @apns_dev_endpoint}, {:prod, @apns_prod_endpoint}]

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec init(Keyword.t()) ::
          {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(raw_apns_config) do
    dev_raw_configs = Keyword.get(raw_apns_config, :dev, [])
    prod_raw_configs = Keyword.get(raw_apns_config, :prod, [])

    pool_configs =
      (get_apns_pool_configs(dev_raw_configs, :dev) ++
         get_apns_pool_configs(prod_raw_configs, :prod))
      |> Enum.with_index()

    children =
      for {{{pool_config, pool_tags}, pool_type}, index} <- pool_configs do
        id = String.to_atom("Sparrow.APNS.Pool.ID." <> Integer.to_string(index))

        %{
          id: id,
          start:
            {Sparrow.H2Worker.Pool, :start_link,
             [pool_config, pool_type, pool_tags]}
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec get_apns_pool_configs(Keyword.t(), :dev | :prod) :: [
          {{Sparrow.H2Worker.Pool.Config.t(), [atom]}, :dev | :prod}
        ]
  defp get_apns_pool_configs(raw_pool_configs, pool_type) do
    for raw_pool_config <- raw_pool_configs do
      {get_apns_pool_config(raw_pool_config, pool_type), {:apns, pool_type}}
    end
  end

  @spec get_apns_pool_config(Keyword.t(), :dev | :prod) ::
          {Sparrow.H2Worker.Pool.Config.t(), [atom]}
  defp get_apns_pool_config(raw_pool_config, pool_type) do
    port = Keyword.get(raw_pool_config, :port, 443)

    tls_opts =
      Keyword.get(raw_pool_config, :tls_opts, setup_default_tls_options())

    ping_interval = Keyword.get(raw_pool_config, :ping_interval, 5000)
    reconnection_attempts = Keyword.get(raw_pool_config, :reconnect_attempts, 3)

    auth =
      case Keyword.get(raw_pool_config, :auth_type) do
        :token_based ->
          raw_pool_config
          |> Keyword.get(:token_id)
          |> Sparrow.APNS.get_token_based_authentication()

        :certificate_based ->
          cert = Keyword.get(raw_pool_config, :cert)
          key = Keyword.get(raw_pool_config, :key)
          Sparrow.H2Worker.Authentication.CertificateBased.new(cert, key)
      end

    pool_name = Keyword.get(raw_pool_config, :pool_name)
    pool_size = Keyword.get(raw_pool_config, :worker_num, 3)
    pool_opts = Keyword.get(raw_pool_config, :raw_opts, [])
    pool_tags = Keyword.get(raw_pool_config, :tags, [])

    uri = Keyword.get(raw_pool_config, :endpoint, @apns_endpoint[pool_type])

    worker_config =
      Sparrow.H2Worker.Config.new(%{
        domain: uri,
        port: port,
        authentication: auth,
        tls_options: tls_opts,
        ping_interval: ping_interval,
        reconnect_attempts: reconnection_attempts
      })

    pool_config =
      Sparrow.H2Worker.Pool.Config.new(
        worker_config,
        pool_name,
        pool_size,
        pool_opts
      )

    {pool_config, pool_tags}
  end

  defp setup_default_tls_options do
    cacerts = :certifi.cacerts()

    [
      {:verify, :verify_peer},
      {:depth, 99},
      {:cacerts, cacerts}
    ]
  end
end
