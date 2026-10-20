defmodule Sparrow.Pool.LifecycleTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup

  test "pool is started as a supervisor" do
    config = pool_config()

    assert %{type: :supervisor, start: {Sparrow.Pool, :start_link, [^config]}} =
             Sparrow.Pool.child_spec(config)
  end

  test "pool started twice returns the first one" do
    config = pool_config()
    {:ok, pid} = Setup.start_pool(config, type: :fcm)

    assert {:error, {:already_started, ^pid}} = Sparrow.Pool.start_link(config)
  end

  # Nothing listens on this port, the pools are only registered
  defp pool_config do
    name = :"lifecycle_pool_#{System.unique_integer([:positive])}"
    config = Setup.create_pool_config(Setup.server_host(), 1, :token_based)
    %{config | name: name}
  end
end
