defmodule Sparrow.PoolsWarden do
  @moduledoc false
  # Pools are found with `Sparrow.Pool.choose/2`

  @type pool_type :: Sparrow.Pool.Config.type()

  @doc false
  @deprecated "Use Sparrow.Pool.choose/2 instead"
  @spec choose_pool(pool_type, [any]) :: atom | nil
  def choose_pool(pool_type, tags \\ []) do
    Sparrow.Pool.choose(pool_type, tags)
  end
end
