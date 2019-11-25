defmodule Sparrow.PoolsWardenTest do
  use ExUnit.Case
  use HelperMacros
  alias Helpers.SetupHelper, as: Tools
  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  @pool_tags [:alpha, :beta, :gamma]
  test "initial pools colections are empty" do
     {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)
    assert nil == Sparrow.PoolsWarden.choose_pool(:fcm)
    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :dev})
    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :prod})
  end

  test "fcm pool is added correctly" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)
    pool_name = Sparrow.PoolsWarden.add_new_pool(self(), :fcm, :name, @pool_tags)
    assert pool_name == Sparrow.PoolsWarden.choose_pool(:fcm)

    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :dev})
    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :prod})
  end

  test "apns dev pool is added correctly" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :dev}, :name, @pool_tags)

    assert pool_name == Sparrow.PoolsWarden.choose_pool({:apns, :dev})
    assert nil == Sparrow.PoolsWarden.choose_pool(:fcm)
    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :prod})
  end

  test "apns prod pool is added correctly" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :prod}, :name, @pool_tags)

    assert pool_name == Sparrow.PoolsWarden.choose_pool({:apns, :prod})
    assert nil == Sparrow.PoolsWarden.choose_pool(:fcm)
    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :dev})
  end

  test "pool with name is not renamed" do
    name = :pools_cool_name
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    ^name = Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :prod}, name, @pool_tags)

    assert name == Sparrow.PoolsWarden.choose_pool({:apns, :prod})
    assert nil == Sparrow.PoolsWarden.choose_pool(:fcm)
    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :dev})
  end

  test "many pools are added correctly" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    apns_prod_1_tags = [:apns_prod_1 | @pool_tags]
    apns_prod_2_tags = [:apns_prod_2 | @pool_tags]
    apns_dev_1_tags = [:apns_dev_1 | @pool_tags]
    apns_dev_2_tags = [:apns_dev_2 | @pool_tags]
    apns_dev_3_tags = [:apns_dev_3 | @pool_tags]
    fcm_1_tags = [:fcm_1 | @pool_tags]
    fcm_2_tags = [:fcm_2 | @pool_tags]

    apns_prod_1_pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :prod}, :a, apns_prod_1_tags)

    _apns_prod_2_pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :prod}, :b, apns_prod_2_tags)

    apns_dev_1_pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :dev}, :c, apns_dev_1_tags)

    _apns_dev_2_pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :dev}, :d, apns_dev_2_tags)

    _apns_dev_3_pool_name =
      Sparrow.PoolsWarden.add_new_pool(self(), {:apns, :dev}, :e, apns_dev_3_tags)

    fcm_1_pool_name = Sparrow.PoolsWarden.add_new_pool(self(), :fcm, :f, fcm_1_tags)
    _fcm_2_pool_name = Sparrow.PoolsWarden.add_new_pool(self(), :fcm, :g, fcm_2_tags)

    apns_dev_pools = Sparrow.PoolsWarden.choose_pool({:apns, :dev})
    apns_prod_pools = Sparrow.PoolsWarden.choose_pool({:apns, :prod})
    fcm_pools = Sparrow.PoolsWarden.choose_pool(:fcm)

    assert apns_dev_1_pool_name == apns_dev_pools
    assert apns_prod_1_pool_name == apns_prod_pools
    assert fcm_1_pool_name == fcm_pools
  end

  test "Pools warden clears messages" do
    {:ok, pid} = start_supervised(Sparrow.PoolsWarden)

    send(pid, :unexpected_message)
    :timer.sleep(100)
    assert {:messages, []} == :erlang.process_info(pid, :messages)
  end

  test "Pools warden deletes ets table when terminates" do
    assert :undefined == :ets.info(:sparrow_pools_warden_tab)
    Sparrow.PoolsWarden.init(:ok)
    assert :undefined != :ets.info(:sparrow_pools_warden_tab)
    Sparrow.PoolsWarden.terminate(:reason, :ok)
    assert :undefined == :ets.info(:sparrow_pools_warden_tab)
  end

  test "choosing APNS pool works correctly" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    pool_1_config =
      Sparrow.APNS.get_token_based_authentication(:token_id)
      |> Sparrow.APNS.get_h2worker_config_dev()
      |> Sparrow.H2Worker.Pool.Config.new()

    pool_1_name = pool_1_config.pool_name

    {:ok, _pid} =
      Sparrow.H2Worker.Pool.start_link(pool_1_config, {:apns, :dev}, [
        :alpha,
        :beta,
        :gamma
      ])

    pool_2_config =
      Sparrow.APNS.get_token_based_authentication(:token_id)
      |> Sparrow.APNS.get_h2worker_config_dev()
      |> Sparrow.H2Worker.Pool.Config.new()

    pool_2_name = pool_2_config.pool_name

    {:ok, _pid} =
      Sparrow.H2Worker.Pool.start_link(pool_2_config, {:apns, :dev}, [
        :beta,
        :gamma,
        :delta,
        :lambda
      ])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:alpha])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:alpha, :beta])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:beta, :alpha])

    assert pool_2_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:lambda])

    assert pool_2_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:delta, :lambda])

    assert pool_2_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:lambda, :delta])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:gamma])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:beta, :gamma])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:gamma, :beta])

    assert nil == Sparrow.PoolsWarden.choose_pool({:apns, :dev}, [:ksi])
  end

  test "choosing FCM pool works correctly" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    pool_1_config =
      Sparrow.FCM.V1.get_token_based_authentication(:token_id)
      |> Sparrow.FCM.V1.get_h2worker_config()
      |> Sparrow.H2Worker.Pool.Config.new()

    pool_1_name = pool_1_config.pool_name

    {:ok, _pid} =
      Sparrow.H2Worker.Pool.start_link(pool_1_config, :fcm, [
        :alpha,
        :beta,
        :gamma
      ])

    pool_2_config =
      Sparrow.FCM.V1.get_token_based_authentication(:token_id)
      |> Sparrow.FCM.V1.get_h2worker_config()
      |> Sparrow.H2Worker.Pool.Config.new()

    pool_2_name = pool_2_config.pool_name

    {:ok, _pid} =
      Sparrow.H2Worker.Pool.start_link(pool_2_config, :fcm, [
        :beta,
        :gamma,
        :delta,
        :lambda
      ])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:alpha])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:alpha, :beta])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:beta, :alpha])

    assert pool_2_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:lambda])

    assert pool_2_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:delta, :lambda])

    assert pool_2_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:lambda, :delta])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:gamma])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:beta, :gamma])

    assert pool_1_name ==
             Sparrow.PoolsWarden.choose_pool(:fcm, [:gamma, :beta])

    assert nil == Sparrow.PoolsWarden.choose_pool(:fcm, [:ksi])
  end

  test "Pools are unregistered when their process is killed" do
    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)
    fake_pool_pid = Process.spawn(fn -> receive do
      :exit ->
        :ok
    end
     end, [:link])

    name = Sparrow.PoolsWarden.add_new_pool(fake_pool_pid, :fcm, :a, [:alpha])

    assert 1 == Keyword.get(:ets.info(:sparrow_pools_warden_tab), :size)
    assert name == Sparrow.PoolsWarden.choose_pool(:fcm)

    send(fake_pool_pid, :exit)

    assert eventually 0 == Keyword.get(:ets.info(:sparrow_pools_warden_tab), :size)
    assert nil == Sparrow.PoolsWarden.choose_pool(:fcm)
  end
end
