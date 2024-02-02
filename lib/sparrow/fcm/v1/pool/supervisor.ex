defmodule Sparrow.FCM.V1.Pool.Supervisor do
  @moduledoc """
  Supervises a single FCM workers pool.
  """
  use Supervisor

  @fcm_default_endpoint "fcm.googleapis.com"
  @account_key "client_email"

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec init(Keyword.t()) ::
          {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(raw_config) do
    pool_configs =
      Enum.map(raw_config, fn single_config ->
        {single_config[:path_to_json], get_fcm_pool_config(single_config)}
      end)

    for {path_to_json, {pool_config, _pool_tags}} <- pool_configs do
      Sparrow.FCM.V1.ProjectIdBearer.add_project_id(
        path_to_json,
        pool_config.pool_name
      )
    end

    children =
      for {{_json, {pool_config, pool_tags}}, index} <-
            Enum.with_index(pool_configs) do
        id = String.to_atom("Sparrow.Fcm.Pool.ID.#{index}")

        %{
          id: id,
          start:
            {Sparrow.H2Worker.Pool, :start_link, [pool_config, :fcm, pool_tags]}
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec get_fcm_pool_config(Keyword.t()) ::
          {Sparrow.H2Worker.Pool.Config.t(), [atom]}
  defp get_fcm_pool_config(raw_pool_config) do
    uri = Keyword.get(raw_pool_config, :endpoint, @fcm_default_endpoint)
    port = Keyword.get(raw_pool_config, :port, 443)

    tls_opts =
      Keyword.get(raw_pool_config, :tls_opts, setup_default_tls_options())

    ping_interval = Keyword.get(raw_pool_config, :ping_interval, 5000)
    reconnection_attempts = Keyword.get(raw_pool_config, :reconnect_attempts, 3)

    pool_tags = Keyword.get(raw_pool_config, :tags, [])
    pool_name = Keyword.get(raw_pool_config, :pool_name)
    pool_size = Keyword.get(raw_pool_config, :worker_num, 3)
    pool_opts = Keyword.get(raw_pool_config, :raw_opts, [])

    account =
      raw_pool_config
      |> Keyword.get(:path_to_json)
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!(@account_key)

    config =
      account
      |> Sparrow.FCM.V1.get_token_based_authentication()
      |> Sparrow.FCM.V1.get_h2worker_config(
        uri,
        port,
        tls_opts,
        ping_interval,
        reconnection_attempts
      )
      |> Sparrow.H2Worker.Pool.Config.new(pool_name, pool_size, pool_opts)

    {config, pool_tags}
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
