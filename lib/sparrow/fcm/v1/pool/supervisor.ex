defmodule Sparrow.FCM.V1.Pool.Supervisor do
  @moduledoc """
  Supervises FCM pools.
  """
  use Supervisor

  alias Sparrow.Pool.Config

  @fcm_default_endpoint "fcm.googleapis.com"
  @account_key "client_email"

  @spec start_link([Keyword.t()]) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec init([Keyword.t()]) ::
          {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(raw_config) do
    pool_configs =
      for {single_config, index} <- Enum.with_index(raw_config) do
        id = String.to_atom("Sparrow.Fcm.Pool.ID.#{index}")

        {id, single_config[:path_to_json],
         get_fcm_pool_config(single_config, id)}
      end

    for {_id, path_to_json, pool_config} <- pool_configs do
      Sparrow.FCM.V1.ProjectIdBearer.add_project_id(
        path_to_json,
        pool_config.name
      )
    end

    children =
      for {id, _json, pool_config} <- pool_configs do
        Supervisor.child_spec({Sparrow.Pool, pool_config}, id: id)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Unnamed pool is named after its child, so it keeps the name on restart
  @spec get_fcm_pool_config(Keyword.t(), atom) :: Config.t()
  defp get_fcm_pool_config(raw_pool_config, default_name) do
    account =
      raw_pool_config
      |> Keyword.get(:path_to_json)
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!(@account_key)

    Config.new(%{
      name: Keyword.get(raw_pool_config, :pool_name, default_name),
      type: :fcm,
      tags: Keyword.get(raw_pool_config, :tags, []),
      domain: Keyword.get(raw_pool_config, :endpoint, @fcm_default_endpoint),
      port: Keyword.get(raw_pool_config, :port, 443),
      authentication: Sparrow.FCM.V1.get_token_based_authentication(account),
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
