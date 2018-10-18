defmodule Sparrow.APNS.Manual.RealIosTest do
  use ExUnit.Case

  alias Sparrow.APNS.Notification
  alias Sparrow.H2Worker.Config

  @device_token System.get_env("TOKENDEVICE")
  @apns_topic System.get_env("APNSTOPIC")
  @key_id System.get_env("KEYID")
  @team_id System.get_env("TEAMID")
  @p8_file_path "test/priv/tokens/apns_token.p8"

  @path_to_cert "test/priv/certs/Certificates1.pem"
  @path_to_key "test/priv/certs/key.pem"

  @title "Commander Cody"
  @body "the time has come. Execute order 66."

  @tag :skip
  test "real notification certificate based authentication test" do
    apns = [
      dev: [
        [
          auth_type: :certificate_based,
          cert: @path_to_cert,
          key: @path_to_key
        ]
      ]
    ]

    start_sparrow_with_apns_config(apns)

    notification =
      @device_token
      |> Notification.new(:dev)
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_topic(@apns_topic)

    assert :ok == Sparrow.API.push(notification)
  end

  @tag :skip
  test "real notification token based authentication test" do
    apns = [
      dev: [
        [
          auth_type: :token_based,
          token_id: :some_atom_id
        ]
      ],
      tokens: [
        [
          token_id: :some_atom_id,
          key_id: @key_id,
          team_id: @team_id,
          p8_file_path: @p8_file_path
        ]
      ]
    ]

    start_sparrow_with_apns_config(apns)

    notification =
      @device_token
      |> Notification.new(:dev)
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_topic(@apns_topic)

    assert :ok == Sparrow.API.push(notification)
  end

  defp start_sparrow_with_apns_config(config) do
    Application.stop(:sparrow)
    Application.put_env(:sparrow, :apns, config)
    Application.start(:sparrow)
  end
end
