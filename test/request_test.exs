defmodule Sparrow.RequestTest do
  use ExUnit.Case

  test "request is created with the given values and the default timeout" do
    assert %Sparrow.Request{
             headers: [{"header", "value"}],
             body: "body",
             path: "/path",
             timeout: 5_000
           } == Sparrow.Request.new([{"header", "value"}], "body", "/path")
  end
end
