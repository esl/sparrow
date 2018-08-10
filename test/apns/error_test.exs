defmodule Sparrow.ErrorTest do
  use ExUnit.Case

  test "unmached state and error_string" do
    status_code = 1234
    error_string = "my test message"

    expected_description =
      "Unameched status code  = #{status_code}, error string = #{error_string}"

    actual_description = Sparrow.APNS.get_error_description(status_code, error_string)

    assert expected_description == actual_description
  end

  test "unmached state" do
    status_code = 1234
    error_string = "BadCollapseId"

    expected_description =
      "Unameched status code  = #{status_code}, error string = #{error_string}"

    actual_description = Sparrow.APNS.get_error_description(status_code, error_string)

    assert expected_description == actual_description
  end

  test "unmached error_string" do
    status_code = 400
    error_string = "my test message"

    expected_description =
      "Unameched status code  = #{status_code}, error string = #{error_string}"

    actual_description = Sparrow.APNS.get_error_description(status_code, error_string)

    assert expected_description == actual_description
  end
end
