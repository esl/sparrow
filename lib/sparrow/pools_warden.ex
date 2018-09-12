defmodule Sparrow.PoolsWarden do
  @moduledoc """
  Module to handle workers pools.
  """

  use GenServer
  require Logger

  @type pool_type :: :fcm | {:apns, :dev} | {:apns, :prod}

  @tab_name :sparrow_pools_warden_tab
  @sparrow_pools_warden_name :sparrow_pools_warden_name

  @doc """
  Function to "register" new workers pool, allows for `Sparrow.API.push/3` to automatically choose pool.

  ## Arguments
      * `pool_type` - determine if pool is FCM or APNS dev or APNS
      * `tags` - tags that allow to call a particular pool of subset of pools
  """
  @spec add_new_pool(pool_type, [any]) :: true
  def add_new_pool(pool_type, tags \\ []) do
    GenServer.call(@sparrow_pools_warden_name, {:add_pool, pool_type, tags})
  end

  @doc """
  Maybe, some day...
  """
  @spec get_pools(pool_type) :: [{atom, [any]}]
  def get_pools(pool_type) do
    :ets.lookup(@tab_name, pool_type)
  end

  @spec get_pool_warden_name() :: :sparrow_pools_warden_name
  def get_pool_warden_name do
    @sparrow_pools_warden_name
  end

  @spec start_link :: GenServer.on_start()
  def start_link do
    GenServer.start_link(Sparrow.PoolsWarden, :ok, [name: @sparrow_pools_warden_name])
  end
  @spec init(any) :: {:ok, :ok}
  def init(_) do
    @tab_name = :ets.new(@tab_name, [:bag, :protected, :named_table])

    _ =
      Logger.info(fn ->
        "worker=pools_warden, action=init, result=success"
      end)

    {:ok, :ok}
  end

  @spec terminate(any, Sparrow.APNS.TokenBearer.State.t()) :: :ok
  def terminate(reason, _state) do
    ets_del = :ets.delete(@tab_name)

    _ =
      Logger.info(fn ->
        "worker=pools_warden, action=terminate, reason=#{inspect(reason)}, ets_delate_result=#{
          inspect(ets_del)
        }"
      end)
  end

  @spec handle_info(any, :ok) :: {:noreply, :ok}
  def handle_info(unknown, _state) do
    _ =
      Logger.warn(fn ->
        "worker=pools_warden, Unknown info #{inspect(unknown)}"
      end)

    {:noreply, :ok}
  end

  @spec handle_call({:add_pool, pool_type, [any]}, GenServer.from, any) :: {:reply, atom, :ok}
  def handle_call({:add_pool, pool_type, tags},_ , _state) do
    pool_name = generate_pool_name(pool_type, tags)
    :ets.insert(@tab_name, {pool_type, {pool_name, tags}})
    {:reply, pool_name, :ok}
  end

  @spec generate_pool_name(pool_type, [any]) :: atom
  defp generate_pool_name(pool_type, tags) do
    inspect(pool_type) <>
        List.foldr(tags, "", fn elem, acc -> acc <> inspect(elem) end) <>
        inspect(:rand.uniform(1_000_000_000_000))
    |> String.to_atom()
  end
end
