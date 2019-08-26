defmodule Sparrow.PoolsWarden do
  @moduledoc """
  Module to handle workers pools.
  """

  use GenServer
  require Logger

  @type pool_type :: :fcm | {:apns, :dev} | {:apns, :prod}

  @tab_name :sparrow_pools_warden_tab

  @doc """
  Function to "register" new workers pool, allows for `Sparrow.API.push/3` to automatically choose pool.

  ## Arguments
      * `pid` - PID of pool process. Needed to unregister pool when its process is killed
      * `pool_type` - determine if pool is FCM or APNS dev or APNS
      * `pool_name` - Name of the pool, chosen internally - for choosing specific pool use `tags`
      * `tags` - tags that allow to call a particular pool of subset of pools
  """
  @spec add_new_pool(pid(), pool_type, atom, [any]) :: true
  def add_new_pool(pid, pool_type, pool_name, tags \\ []) do
    GenServer.call(
      __MODULE__,
      {:add_pool, pid, pool_type, pool_name, tags}
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
        "worker=pools_warden, action=choose_pool, result=#{inspect(result)}, result_len=#{
          inspect(Enum.count(result))
        }"
      end)

    List.first(result)
  end

  @spec start_link(any) :: GenServer.on_start()
  def start_link(_) do
    start_link()
  end

  @spec start_link :: GenServer.on_start()
  def start_link do
    GenServer.start_link(
      Sparrow.PoolsWarden,
      :ok,
      name: __MODULE__
    )
  end

  @impl GenServer
  def init(_) do
    @tab_name = :ets.new(@tab_name, [:bag, :protected, :named_table])

    _ =
      Logger.info(fn ->
        "worker=pools_warden, action=init, result=success"
      end)

    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, _state) do
    ets_del = :ets.delete(@tab_name)

    _ =
      Logger.info(fn ->
        "worker=pools_warden, action=terminate, reason=#{inspect(reason)}, ets_delate_result=#{
          inspect(ets_del)
        }"
      end)
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    [pool_type, pool_name, tags] = Map.get(state, pid)
    :ets.delete_object(@tab_name, {pool_type, {pool_name, tags}})

    _ =
      Logger.info(fn ->
        "worker=pools_warden, action=unregistering pool,
        ets_table=#{inspect(:ets.info(@tab_name))},
        pid=#{inspect(pid)}, reason=#{inspect(reason)}"
      end)

    {:noreply, Map.delete(state, pid)}
  end

  def handle_info(unknown, state) do
    _ =
      Logger.warn(fn ->
        "worker=pools_warden, Unknown info #{inspect(unknown)}"
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:add_pool, pid, pool_type, pool_name, tags}, _, state) do
    Process.monitor(pid)
    :ets.insert(@tab_name, {pool_type, {pool_name, tags}})

    _ =
      Logger.info(fn ->
        "worker=pools_warden, action=adding_pool, pool_type=#{
          inspect(pool_type)
        }, pool_name=#{inspect(pool_name)}, pool_tags=#{inspect(tags)}"
      end)
    {:reply, pool_name, Map.merge(state, %{pid => [pool_type, pool_name, tags]})}
  end

  @spec get_pools(pool_type) :: [{atom, [any]}]
  defp get_pools(pool_type) do
    :ets.lookup(@tab_name, pool_type)
  end
end
