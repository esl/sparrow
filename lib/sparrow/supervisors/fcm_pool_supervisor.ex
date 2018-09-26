defmodule Sparrow.FCMPoolSupervisor do
  @moduledoc """
  Supervises a single FCM workers pool.
  """
  use Supervisor

  @spec start_link([{atom, any}]) :: Supervisor.on_start()
  def start_link(arg) do
    init(arg)
  end

  @spec init([{atom, any}]) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(raw_config) do
    pool_config = get_fcm_pool_config(raw_config)

    children = [
      %{
        id: Sparrow.H2Worker.Pool,
        start: {Sparrow.H2Worker.Pool, :start_link, [pool_config]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @spec get_fcm_pool_config([{atom, any}]) :: Sparrow.H2Worker.Pool.Config.t()
  defp get_fcm_pool_config(raw_pool_config) do
    uri = Keyword.get(raw_pool_config, :endpoint, "fcm.googleapis.com")
    port = Keyword.get(raw_pool_config, :port, 443)
    tls_opts = Keyword.get(raw_pool_config, :tls_opts, [])
    ping_interval = Keyword.get(raw_pool_config, :ping_interval, 5000)
    reconnection_attempts = Keyword.get(raw_pool_config, :reconnect_attempts, 3)

    pool_name = Keyword.get(raw_pool_config, :pool_name)
    pool_size = Keyword.get(raw_pool_config, :pool_size, 3)
    pool_opts = Keyword.get(raw_pool_config, :raw_opts, [])

    Sparrow.FCM.V1.get_token_based_authentication()
    |> Sparrow.FCM.V1.get_h2worker_config(
      uri,
      port,
      tls_opts,
      ping_interval,
      reconnection_attempts
    )
    |> Sparrow.H2Worker.Pool.Config.new(pool_name, pool_size, pool_opts)
  end
end
