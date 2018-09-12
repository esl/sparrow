defmodule Sparrow.PoolsWardenTest do
  use ExUnit.Case

  @pool_tags [:alpha, :beta, :gamma]
  test "initial pools colections are empty" do
    {:ok, _pid} = Sparrow.PoolsWarden.start_link()
    assert [] == Sparrow.PoolsWarden.get_pools(:fcm)
    assert [] == Sparrow.PoolsWarden.get_pools({:apns, :dev})
    assert [] == Sparrow.PoolsWarden.get_pools({:apns, :prod})
  end

  test "fcm pool is added correctly" do
    {:ok, _pid} = Sparrow.PoolsWarden.start_link()
    pool_name = Sparrow.PoolsWarden.add_new_pool(:fcm, @pool_tags)
    [fcm: {^pool_name, @pool_tags}] = Sparrow.PoolsWarden.get_pools(:fcm)
    assert [] == Sparrow.PoolsWarden.get_pools({:apns, :dev})
    assert [] == Sparrow.PoolsWarden.get_pools({:apns, :prod})
  end

  test "apns dev pool is added correctly" do
    {:ok, _pid} = Sparrow.PoolsWarden.start_link()
    pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :dev}, @pool_tags)
    [{{:apns, :dev}, {^pool_name, @pool_tags}}] = Sparrow.PoolsWarden.get_pools({:apns, :dev})
    assert [] == Sparrow.PoolsWarden.get_pools(:fcm)
    assert [] == Sparrow.PoolsWarden.get_pools({:apns, :prod})
  end

  test "apns prod pool is added correctly" do
    {:ok, _pid} = Sparrow.PoolsWarden.start_link()
    pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :prod}, @pool_tags)
    [{{:apns, :prod}, {^pool_name, @pool_tags}}] = Sparrow.PoolsWarden.get_pools({:apns, :prod})
    assert [] == Sparrow.PoolsWarden.get_pools(:fcm)
    assert [] == Sparrow.PoolsWarden.get_pools({:apns, :dev})
  end

  test "many pools are added correctly" do
    {:ok, _pid} = Sparrow.PoolsWarden.start_link()
    apns_prod_1_tags = [:apns_prod_1 | @pool_tags]
    apns_prod_2_tags = [:apns_prod_2 | @pool_tags]
    apns_dev_1_tags = [:apns_dev_1 | @pool_tags]
    apns_dev_2_tags = [:apns_dev_2 | @pool_tags]
    apns_dev_3_tags = [:apns_dev_3 | @pool_tags]
    fcm_1_tags = [:fcm_1 | @pool_tags]
    fcm_2_tags = [:fcm_2 | @pool_tags]
    apns_prod_1_pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :prod}, apns_prod_1_tags)
    apns_prod_2_pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :prod}, apns_prod_2_tags)
    apns_dev_1_pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :dev}, apns_dev_1_tags)
    apns_dev_2_pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :dev}, apns_dev_2_tags)
    apns_dev_3_pool_name = Sparrow.PoolsWarden.add_new_pool({:apns, :dev}, apns_dev_3_tags)
    fcm_1_pool_name = Sparrow.PoolsWarden.add_new_pool(:fcm, fcm_1_tags)
    fcm_2_pool_name = Sparrow.PoolsWarden.add_new_pool(:fcm, fcm_2_tags)

    apns_dev_pools = Sparrow.PoolsWarden.get_pools({:apns,:dev})
    apns_prod_pools = Sparrow.PoolsWarden.get_pools({:apns,:prod})
    fcm_pools = Sparrow.PoolsWarden.get_pools(:fcm)
    assert {{:apns,:dev}, {apns_dev_1_pool_name, apns_dev_1_tags}} in apns_dev_pools
    assert {{:apns,:dev}, {apns_dev_2_pool_name, apns_dev_2_tags}} in apns_dev_pools
    assert {{:apns,:dev}, {apns_dev_3_pool_name, apns_dev_3_tags}} in apns_dev_pools
    assert {{:apns,:prod}, {apns_prod_1_pool_name, apns_prod_1_tags}} in apns_prod_pools
    assert {{:apns,:prod}, {apns_prod_2_pool_name, apns_prod_2_tags}} in apns_prod_pools
    assert {:fcm, {fcm_1_pool_name, fcm_1_tags}} in fcm_pools
    assert {:fcm, {fcm_2_pool_name, fcm_2_tags}} in fcm_pools
  end

  test "Pools warden clears messages up" do
    {:ok, pid} = Sparrow.PoolsWarden.start_link()
    send pid, :unexpected_message
    :timer.sleep(100)
    assert {:messages, []} == :erlang.process_info(pid, :messages)
  end
end
