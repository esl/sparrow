defmodule Sparrow.APNSSupervisor do
  @moduledoc """
  Main APNS supervisor.
  Supervises APNS tokens bearer and pool supervisors.
  """
  use Supervisor

  @spec start_link([{atom, any}]) :: Supervisor.on_start()
  def start_link(arg) do
    init(arg)
  end

  @spec init([{atom, any}]) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(raw_apns_config) do
    tokens = get_apns_tokens(raw_apns_config)

    dev_raw_configs = Keyword.get(raw_apns_config, :dev)
    prod_raw_configs = Keyword.get(raw_apns_config, :prod)

    pool_configs =
      get_apns_pool_configs(dev_raw_configs, :dev) ++
        get_apns_pool_configs(prod_raw_configs, :prod)

    children =
      for {{pool_config, pool_tags}, pool_type} <- pool_configs do
        pool_id = ".APNS." <> Integer.to_string(get_next())
        id = String.to_atom("Sparrow.APNSPoolSupervisor" <> pool_id)

        %{
          id: id,
          type: :supervisor,
          start:
            {Sparrow.APNSPoolSupervisor, :start_link,
             [{pool_id, pool_config, {:apns, pool_type}, pool_tags}]}
        }
      end ++
        [
          %{
            id: Sparrow.APNS.TokenBearer,
            start: {Sparrow.APNS.TokenBearer, :start_link, [tokens]}
          }
        ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @spec get_apns_tokens([{atom, any}]) :: %{
          required(atom) => Sparrow.APNS.Token.t()
        }
  defp get_apns_tokens(raw_apns_config) do
    token_configs = Keyword.get(raw_apns_config, :tokens, [])

    for token_config <- token_configs do
      get_apns_token(token_config)
    end
    |> Map.new()
  end

  @spec get_apns_token([{atom, any}]) :: {atom, Sparrow.APNS.Token.t()}
  defp get_apns_token(token_config) do
    token_id = Keyword.get(token_config, :token_id)
    team_id = Keyword.get(token_config, :team_id)
    key_id = Keyword.get(token_config, :key_id)
    p8_file_path = Keyword.get(token_config, :p8_file_path)
    {token_id, Sparrow.APNS.Token.new(team_id, key_id, p8_file_path)}
  end

  @spec get_next() :: non_neg_integer
  defp get_next do
    result =
      case :erlang.get(:pool_id_counter) do
        :undefined -> 0
        n -> n
      end

    :erlang.put(:pool_id_counter, result + 1)
    result
  end

  @spec get_apns_pool_configs(nil | [{atom, any}], :dev | :prod) :: [
          {{Sparrow.H2Worker.Pool.Config.t(), [atom]}, :dev | :prod}
        ]
  defp get_apns_pool_configs(nil, _), do: []

  defp get_apns_pool_configs(raw_pool_configs, pool_type) do
    for raw_pool_config <- raw_pool_configs do
      {get_apns_pool_config(raw_pool_config, pool_type), pool_type}
    end
  end

  @spec get_apns_pool_config([{atom, any}], :dev | :prod) ::
          {Sparrow.H2Worker.Pool.Config.t(), [atom]}
  defp get_apns_pool_config(raw_pool_config, pool_type) do
    uri =
      case pool_type do
        :dev ->
          Keyword.get(
            raw_pool_config,
            :endpoint,
            "api.development.push.apple.com"
          )

        :prod ->
          Keyword.get(raw_pool_config, :endpoint, "api.push.apple.com")
      end

    port = Keyword.get(raw_pool_config, :port, 443)
    tls_opts = Keyword.get(raw_pool_config, :tls_opts, [])
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

    config =
      uri
      |> Sparrow.H2Worker.Config.new(
        port,
        auth,
        tls_opts,
        ping_interval,
        reconnection_attempts
      )
      |> Sparrow.H2Worker.Pool.Config.new(pool_name, pool_size, pool_opts)

    {config, pool_tags}
  end
end
