defmodule H2Integration.Helpers.TokenHelper do
  @moduledoc false
  def get_correct_token do
    "Authentication_passed_token"
  end

  def get_incorrect_token do
    "Authentication_failed_token"
  end

  def get_correct_token_response_body do
    "Authorised"
  end

  def get_incorrect_token_response_body do
    "Not Authorised"
  end
end
