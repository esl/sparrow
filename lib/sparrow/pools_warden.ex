defmodule Sparrow.PoolsWarden do
  @moduledoc """
  Module to handle workers pools.
  """

  use GenServer
  use Sparrow.Telemetry.Timer
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
      Logger.debug("Selecting connection pool",
        worker: :pools_warden,
        what: :choose_pool,
        result: result,
        result_len: Enum.count(result)
      )

    chosen_pool = List.first(result)

    :telemetry.execute(
      [:sparrow, :pools_warden, :choose_pool],
      %{},
      %{
        pool_name: chosen_pool,
        pool_type: pool_type,
        pool_tags: tags
      }
    )

    chosen_pool
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
      Logger.info("Starting PoolsWarden",
        worker: :pools_warden,
        what: :init,
        result: :success
      )

    :telemetry.execute(
      [:sparrow, :pools_warden, :init],
      %{},
      %{}
    )

    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, _state) do
    ets_del = :ets.delete(@tab_name)

    _ =
      Logger.info("Shutting down PoolsWarden",
        worker: :pools_warden,
        what: :terminate,
        reason: inspect(reason),
        ets_delate_result: inspect(ets_del)
      )

    :telemetry.execute(
      [:sparrow, :pools_warden, :terminate],
      %{},
      %{reason: reason}
    )
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    [pool_type, pool_name, tags] = Map.get(state, pid)
    :ets.delete_object(@tab_name, {pool_type, {pool_name, tags}})

    _ =
      Logger.info("Pool down",
        worker: :pools_warden,
        what: :pool_down,
        pid: inspect(pid),
        reason: inspect(reason)
      )

    new_state = Map.delete(state, pid)

    :telemetry.execute(
      [:sparrow, :pools_warden, :pool_down],
      %{},
      %{
        pool_name: pool_name,
        pool_type: pool_type,
        pool_tags: tags,
        reason: reason
      }
    )

    {:noreply, new_state}
  end

  def handle_info(unknown, state) do
    _ =
      Logger.warning("Unknown message",
        worker: :pools_warden,
        what: :unknown_message,
        message: inspect(unknown)
      )

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:add_pool, pid, pool_type, pool_name, tags}, _, state) do
    Process.monitor(pid)
    :ets.insert(@tab_name, {pool_type, {pool_name, tags}})

    _ =
      Logger.info("Pool added",
        worker: :pools_warden,
        what: :adding_pool,
        pool_type: pool_type,
        pool_name: pool_name,
        pool_tags: tags
      )

    new_state = Map.merge(state, %{pid => [pool_type, pool_name, tags]})

    :telemetry.execute(
      [:sparrow, :pools_warden, :add_pool],
      %{},
      %{
        pool_name: pool_name,
        pool_type: pool_type,
        pool_tags: tags
      }
    )

    {:reply, pool_name, new_state}
  end

  @spec get_pools(pool_type) :: [{atom, [any]}]
  defp get_pools(pool_type) do
    :ets.lookup(@tab_name, pool_type)
  end
end
