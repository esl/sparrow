defmodule Sparrow.ErrorTest do
  use ExUnit.Case

  test "unmatched state and error_string" do
    status_code = 1234
    error_string = "my test message"

    expected_description =
      "Unmatched status code  = #{status_code}, error string = #{error_string}"

    actual_description = Sparrow.APNS.get_error_description(status_code, error_string)

    assert expected_description == actual_description
  end

  test "unmatched state" do
    status_code = 1234
    error_string = "BadCollapseId"

    expected_description =
      "Unmatched status code  = #{status_code}, error string = #{error_string}"

    actual_description = Sparrow.APNS.get_error_description(status_code, error_string)

    assert expected_description == actual_description
  end

  test "unmatched error_string" do
    status_code = 400
    error_string = "my test message"

    expected_description =
      "Unmatched status code  = #{status_code}, error string = #{error_string}"

    actual_description = Sparrow.APNS.get_error_description(status_code, error_string)

    assert expected_description == actual_description
  end
end
