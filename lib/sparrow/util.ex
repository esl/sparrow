defmodule Sparrow.Util do
  @moduledoc "Utilities for building notifications"

  @spec add_if_not_empty(map, term, map) :: map
  def add_if_not_empty(map, _key, sub_map) when map_size(sub_map) == 0 do
    map
  end

  def add_if_not_empty(map, key, sub_map) do
    Map.put(map, key, sub_map)
  end
end
