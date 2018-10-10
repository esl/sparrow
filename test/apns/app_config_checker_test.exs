defmodule Sparrow.APNS.AppConfigCheckerTest do
  use ExUnit.Case

  @cert_path "priv/ssl/client_cert.pem"
  @key_path "priv/ssl/client_key.pem"
  @wrong_cert_path "wrong/priv/ssl/client_cert.pem"
  @wrong_key_path "wrong/priv/ssl/client_key.pem"

  @wrong_cert_config [
    auth_type: :certificate_based,
    cert: @wrong_cert_path,
    key: @key_path
  ]
  @wrong_key_config [
    auth_type: :certificate_based,
    cert: @cert_path,
    key: @wrong_key_path
  ]

  @wrong_key_and_cert_config [
    auth_type: :certificate_based,
    cert: @wrong_cert_path,
    key: @wrong_key_path
  ]

  @correct_token [
    token_id: :correct_token_id,
    key_id: "FAKE_KEY_ID",
    team_id: "FAKE_TEAM_ID",
    p8_file_path: "token.p8"
  ]

  @wrong_token [
    token_id: :some_atom_id,
    key_id: "FAKE_KEY_ID",
    team_id: "FAKE_TEAM_ID",
    p8_file_path: "wrong/token.p8"
  ]

  test "APNS empty config is correct" do
    assert [] ==
             Sparrow.H2Worker.Pool.AppConfigChecker.validate_config(
               [],
               Sparrow.APNS.AppConfigChecker
             )
  end

  test "APNS wrong cert path in config" do
    config = [
      dev: [
        @wrong_cert_config
      ]
    ]

    assert [@wrong_cert_config] ==
             Sparrow.H2Worker.Pool.AppConfigChecker.validate_config(
               config,
               Sparrow.APNS.AppConfigChecker
             )
  end

  test "APNS wrong key path in config" do
    config = [
      dev: [
        @wrong_key_config
      ]
    ]

    assert [@wrong_key_config] ==
             Sparrow.H2Worker.Pool.AppConfigChecker.validate_config(
               config,
               Sparrow.APNS.AppConfigChecker
             )
  end

  test "APNS wrong cert and key path in config" do
    config = [
      dev: [
        @wrong_key_and_cert_config
      ],
      tokens: [
        @correct_token
      ]
    ]

    assert [@wrong_key_and_cert_config] ==
             Sparrow.H2Worker.Pool.AppConfigChecker.validate_config(
               config,
               Sparrow.APNS.AppConfigChecker
             )
  end

  test "APNS correct token is duplicated" do
    config = [
      tokens: [
        @correct_token,
        @correct_token
      ]
    ]

    assert [{:error, {:duplicated_token_id, :correct_token_id}}] ==
             Sparrow.H2Worker.Pool.AppConfigChecker.validate_config(
               config,
               Sparrow.APNS.AppConfigChecker
             )
  end

  test "APNS incorrect token" do
    config = [
      tokens: [
        @wrong_token,
        @correct_token
      ]
    ]

    assert [@wrong_token] ==
             Sparrow.H2Worker.Pool.AppConfigChecker.validate_config(
               config,
               Sparrow.APNS.AppConfigChecker
             )
  end
end
