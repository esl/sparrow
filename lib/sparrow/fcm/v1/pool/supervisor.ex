defmodule Sparrow.FCM.V1.Pool.Supervisor do
  @moduledoc """
  Supervises a single FCM workers pool.
  """
  use Supervisor

  @fcm_default_endpoint "fcm.googleapis.com"

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec init(Keyword.t()) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
  def init(raw_config) do
    {pool_config, pool_tags} = get_fcm_pool_config(raw_config)

    children = [
      %{
        id: Sparrow.H2Worker.Pool,
        start:
          {Sparrow.H2Worker.Pool, :start_link, [pool_config, :fcm, pool_tags]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec get_fcm_pool_config(Keyword.t()) ::
          {Sparrow.H2Worker.Pool.Config.t(), [atom]}
  defp get_fcm_pool_config(raw_pool_config) do
    uri = Keyword.get(raw_pool_config, :endpoint, @fcm_default_endpoint)
    port = Keyword.get(raw_pool_config, :port, 443)
    tls_opts = Keyword.get(raw_pool_config, :tls_opts, [])
    ping_interval = Keyword.get(raw_pool_config, :ping_interval, 5000)
    reconnection_attempts = Keyword.get(raw_pool_config, :reconnect_attempts, 3)

    pool_name = Keyword.get(raw_pool_config, :pool_name)
    pool_size = Keyword.get(raw_pool_config, :worker_num, 3)
    pool_opts = Keyword.get(raw_pool_config, :raw_opts, [])
    pool_tags = Keyword.get(raw_pool_config, :tags, [])

    config =
      Sparrow.FCM.V1.get_token_based_authentication()
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
end
