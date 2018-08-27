defmodule Sparrow.FCM.V1.NotificationTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.AndroidConfig
  alias Sparrow.FCM.V1.Notification

  test "notification with android config" do
    data = %{:key => :value}

    android_config =
      AndroidConfig.new()
      |> AndroidConfig.add_collapse_key("collapse_key")
      |> AndroidConfig.add_color("color")

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        "title",
        "body",
        :token,
        "target",
        "project_id",
        data
      )
      |> Notification.add_android_config(android_config)

    assert fcm_notification.project_id == "project_id"
    assert fcm_notification.title == "title"
    assert fcm_notification.body == "body"
    assert fcm_notification.target == "target"
    assert fcm_notification.android_config == android_config
    assert fcm_notification.data == data
  end
end
