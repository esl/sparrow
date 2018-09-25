defmodule Sparrow.ErrorTest do
  use ExUnit.Case

  test "unmatched error" do
    error = :Unknown

    expected_description = "Unmatched error = #{inspect(error)}"

    actual_description = Sparrow.APNS.get_error_description(error)

    assert expected_description == actual_description
  end
end
