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
  @spec add_new_pool(pool_type, atom, [any]) :: true
  def add_new_pool(pool_type, pool_name, tags \\ []) do
    GenServer.call(
      @sparrow_pools_warden_name,
      {:add_pool, pool_type, pool_name, tags}
    )
  end

  @doc """
  Function to get all pools of certain `pool_type`.

  ## Arguments
      * `pool_type` - can be one of:
          * `:fcm` - to get FCM pools
          * `{:apns, :dev}` - to get APNS development pools
          * `{:apns, :prod}` - to get APNS production pools
      * `tags` - allows to filter pools, if tags are included only pools with all of these tags are selected
  """

  @spec choose_pool(pool_type, [any]) :: atom | nil
  def choose_pool(pool_type, tags \\ []) do
    pools = get_pools(pool_type)

    result =
      for {_pool_type, {pool_name, pool_tags}} <- pools,
          Enum.all?(tags, fn e -> e in pool_tags end) do
        pool_name
      end

    _ =
      Logger.debug(fn ->
        "worker=pools_warden, action=choose_pool, result=result, result_len=#{
          inspect(Enum.count(result))
        }"
      end)

    List.first(result)
  end

  @doc """
  Function to access `Sparrow.PoolsWarden` by name.
  """
  @spec get_pool_warden_name() :: :sparrow_pools_warden_name
  def get_pool_warden_name do
    @sparrow_pools_warden_name
  end

  @spec start_link :: GenServer.on_start()
  def start_link do
    GenServer.start_link(
      Sparrow.PoolsWarden,
      :ok,
      name: @sparrow_pools_warden_name
    )
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

  @spec terminate(any, :ok) :: :ok
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

  @spec handle_call(
          {:add_pool, pool_type, atom, [any]},
          GenServer.from(),
          any
        ) :: {:reply, atom, :ok}

  def handle_call({:add_pool, pool_type, pool_name, tags}, _, _state) do
    :ets.insert(@tab_name, {pool_type, {pool_name, tags}})
    {:reply, pool_name, :ok}
  end

  @spec get_pools(pool_type) :: [{atom, [any]}]
  defp get_pools(pool_type) do
    :ets.lookup(@tab_name, pool_type)
  end
end
