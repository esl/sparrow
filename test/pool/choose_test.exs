defmodule Sparrow.Pool.ChooseTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup

  @tags [:alpha, :beta, :gamma]

  test "no pool is chosen when there are no pools" do
    assert nil == Sparrow.Pool.choose(:fcm)
    assert nil == Sparrow.Pool.choose({:apns, :dev})
    assert nil == Sparrow.Pool.choose({:apns, :prod})
  end

  test "pool is chosen by its type" do
    fcm = start_pool(:fcm)
    apns_dev = start_pool({:apns, :dev})
    apns_prod = start_pool({:apns, :prod})

    assert fcm == Sparrow.Pool.choose(:fcm)
    assert apns_dev == Sparrow.Pool.choose({:apns, :dev})
    assert apns_prod == Sparrow.Pool.choose({:apns, :prod})
  end

  test "pool without a type is not chosen" do
    start_pool(nil, @tags)

    assert nil == Sparrow.Pool.choose(:fcm, @tags)
    assert nil == Sparrow.Pool.choose({:apns, :dev}, @tags)
  end

  test "pool is chosen when it has all given tags" do
    pool = start_pool(:fcm, @tags)

    assert pool == Sparrow.Pool.choose(:fcm)
    assert pool == Sparrow.Pool.choose(:fcm, [])
    assert pool == Sparrow.Pool.choose(:fcm, [:alpha])
    assert pool == Sparrow.Pool.choose(:fcm, [:gamma, :alpha])
    assert pool == Sparrow.Pool.choose(:fcm, @tags)
    assert nil == Sparrow.Pool.choose(:fcm, [:delta])
    assert nil == Sparrow.Pool.choose(:fcm, [:alpha, :delta])
  end

  test "pools of the same type are told apart by tags" do
    for type <- [:fcm, {:apns, :dev}, {:apns, :prod}] do
      pool_1 = start_pool(type, [:first | @tags])
      pool_2 = start_pool(type, [:second | @tags])

      assert pool_1 == Sparrow.Pool.choose(type, [:first])
      assert pool_2 == Sparrow.Pool.choose(type, [:second])
      assert pool_2 == Sparrow.Pool.choose(type, [:second, :alpha])
      assert pool_1 == Sparrow.Pool.choose(type, @tags)
      assert nil == Sparrow.Pool.choose(type, [:first, :second])
    end
  end

  test "pools of different types with the same tags are told apart" do
    fcm = start_pool(:fcm, @tags)
    apns = start_pool({:apns, :dev}, @tags)

    assert fcm == Sparrow.Pool.choose(:fcm, @tags)
    assert apns == Sparrow.Pool.choose({:apns, :dev}, @tags)
    assert nil == Sparrow.Pool.choose({:apns, :prod}, @tags)
  end

  test "the pool which was started first is chosen" do
    [first | _] = for _ <- 1..5, do: start_pool(:fcm, @tags)

    for _ <- 1..10 do
      assert first == Sparrow.Pool.choose(:fcm, @tags)
    end
  end

  test "stopped pool is not chosen" do
    config = pool_config()
    {:ok, _pid} = Setup.start_pool(config, type: :fcm, tags: @tags)
    assert config.name == Sparrow.Pool.choose(:fcm, @tags)

    :ok = stop_supervised({Sparrow.Pool, config.name})

    assert nil == Sparrow.Pool.choose(:fcm, @tags)
    assert nil == Sparrow.Pool.stats(config.name)
  end

  test "pool cannot be started with a name which is already used" do
    config = pool_config()
    {:ok, _pid} = Setup.start_pool(config, type: :fcm)

    assert {:error, {:already_started, pid}} = Sparrow.Pool.start_link(config)
    assert is_pid(pid)
    assert config.name == Sparrow.Pool.choose(:fcm)
  end

  test "choice is reported" do
    Setup.forward_telemetry([:sparrow, :pools_warden, :choose_pool])
    pool = start_pool(:fcm, @tags)

    Sparrow.Pool.choose(:fcm, [:alpha])

    assert_receive {[:sparrow, :pools_warden, :choose_pool], %{},
                    %{pool_name: ^pool, pool_type: :fcm, pool_tags: [:alpha]}}

    Sparrow.Pool.choose(:fcm, [:delta])

    assert_receive {[:sparrow, :pools_warden, :choose_pool], %{},
                    %{pool_name: nil, pool_type: :fcm, pool_tags: [:delta]}}
  end

  test "all pools are included in stats" do
    assert [] == Sparrow.Pool.stats()

    fcm = start_pool(:fcm)
    untyped = start_pool(nil)

    assert Enum.sort([fcm, untyped]) ==
             Sparrow.Pool.stats() |> Enum.map(& &1.pool) |> Enum.sort()
  end

  defp start_pool(type, tags \\ []) do
    config = pool_config()
    {:ok, _pid} = Setup.start_pool(config, type: type, tags: tags)
    config.name
  end

  # Nothing listens on this port, the pools are only registered
  defp pool_config do
    Setup.create_pool_config(Setup.server_host(), 1, :token_based)
  end
end
