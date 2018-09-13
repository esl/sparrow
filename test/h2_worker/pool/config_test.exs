defmodule Sparrow.H2Worker.Pool.ConfigTest do
  use ExUnit.Case

  test "create new config with known name" do
    auth =
      Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
        {"authorization", "bearer dummy token"}
      end)

    workers_config = Sparrow.H2Worker.Config.new("fake.url.com", 1234, auth)
    pool_name = :my_pool_name
    worker_num = 10
    raw_opts = []

    config =
      Sparrow.H2Worker.Pool.Config.new(
        workers_config,
        pool_name,
        worker_num,
        raw_opts
      )

    assert pool_name == config.pool_name
    assert worker_num == config.worker_num
    assert workers_config == config.workers_config
    assert raw_opts == config.raw_opts
  end

  test "create new config with nil name" do
    auth =
      Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
        {"authorization", "bearer dummy token"}
      end)

    workers_config = Sparrow.H2Worker.Config.new("fake.url.com", 1234, auth)
    config = Sparrow.H2Worker.Pool.Config.new(workers_config, nil)
    assert nil != config.pool_name
    assert is_atom(config.pool_name)
    assert 3 == config.worker_num
    assert workers_config == config.workers_config
    assert [] == config.raw_opts
  end
end
