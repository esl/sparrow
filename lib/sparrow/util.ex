defmodule Sparrow.Util do
  @moduledoc "Utilities for building notifications"

  @spec add_if_not_empty(map, term, map) :: map
  def add_if_not_empty(map, key, sub_map) do
    case sub_map == %{} do
      true -> map
      false -> Map.put(map, key, sub_map)
    end
  end
end
