defmodule SparrowTest do
  use ExUnit.Case
  doctest Sparrow

  test "greets the world" do
    assert Sparrow.hello() == :world
  end
end
