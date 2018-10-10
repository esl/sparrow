defmodule Sparrow.H2Worker.Pool.AppConfigCheckerTest do
  use ExUnit.Case
  @cert_path "priv/ssl/client_cert.pem"
  @key_path "priv/ssl/client_key.pem"

  @basic_config [
    auth_type: :certificate_based,
    cert: @cert_path,
    key: @key_path
  ]

  test "APNS empty config is correct" do
    :ok
  end
end
