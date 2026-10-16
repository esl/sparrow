defmodule Sparrow.APNS.Pool.Supervisor do
  @moduledoc """
  Supervises APNS pools.
  """
  use Supervisor

  alias Sparrow.Pool.Config

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
    raw_pool_configs =
      for pool_type <- [:dev, :prod],
          raw_pool_config <- Keyword.get(raw_apns_config, pool_type, []) do
        {raw_pool_config, pool_type}
      end

    children =
      for {{raw_pool_config, pool_type}, index} <-
            Enum.with_index(raw_pool_configs) do
        id = String.to_atom("Sparrow.APNS.Pool.ID." <> Integer.to_string(index))
        pool_config = get_apns_pool_config(raw_pool_config, pool_type, id)

        Supervisor.child_spec({Sparrow.Pool, pool_config}, id: id)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Unnamed pool is named after its child, so it keeps the name on restart
  @spec get_apns_pool_config(Keyword.t(), :dev | :prod, atom) :: Config.t()
  defp get_apns_pool_config(raw_pool_config, pool_type, default_name) do
    auth =
      case Keyword.get(raw_pool_config, :auth_type) do
        :token_based ->
          raw_pool_config
          |> Keyword.get(:token_id)
          |> Sparrow.APNS.get_token_based_authentication()

        :certificate_based ->
          cert = Keyword.get(raw_pool_config, :cert)
          key = Keyword.get(raw_pool_config, :key)
          Sparrow.Authentication.CertificateBased.new(cert, key)
      end

    Config.new(%{
      name: Keyword.get(raw_pool_config, :pool_name, default_name),
      type: {:apns, pool_type},
      tags: Keyword.get(raw_pool_config, :tags, []),
      domain:
        Keyword.get(raw_pool_config, :endpoint, @apns_endpoint[pool_type]),
      port: Keyword.get(raw_pool_config, :port, 443),
      authentication: auth,
      tls_options:
        Keyword.get(raw_pool_config, :tls_opts, setup_default_tls_options()),
      connections: Keyword.get(raw_pool_config, :worker_num, 3),
      ping_interval: Keyword.get(raw_pool_config, :ping_interval, 5000)
    })
  end

  defp setup_default_tls_options do
    cacerts = :certifi.cacerts()

    [
      {:verify, :verify_peer},
      {:depth, 99},
      {:cacerts, cacerts},
      {:customize_hostname_check,
       [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]}
    ]
  end
end
