defmodule Sparrow.FCM.V1.NotificationTest do
  use ExUnit.Case

  alias Sparrow.APNS.Notification, as: APNSNotification
  alias Sparrow.FCM.V1.AndroidConfig
  alias Sparrow.FCM.V1.APNSConfig
  alias Sparrow.FCM.V1.WebpushConfig
  alias Sparrow.FCM.V1.Notification

  @title "test title"
  @body "test body"
  @target "test target"
  @project_id "test project_id"
  @data %{:keyA => :valueA, :B => :b}

  test "notification without any config" do
    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        @title,
        @body,
        :token,
        @target,
        @project_id,
        @data
      )

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android_config == nil
    assert fcm_notification.webpush_config == nil
    assert fcm_notification.apns_config == nil
    assert fcm_notification.data == @data
  end

  test "notification with android config" do
    android_config =
      AndroidConfig.new()
      |> AndroidConfig.add_collapse_key("collapse_key")
      |> AndroidConfig.add_color("color")

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        @title,
        @body,
        :token,
        @target,
        @project_id,
        @data
      )
      |> Notification.add_android_config(android_config)

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android_config == android_config
    assert fcm_notification.webpush_config == nil
    assert fcm_notification.apns_config == nil
    assert fcm_notification.data == @data
  end

  test "notification with webpush config" do
    webpush_config = WebpushConfig.new("link")

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        @title,
        @body,
        :token,
        @target,
        @project_id,
        @data
      )
      |> Notification.add_webpush_config(webpush_config)

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android_config == nil
    assert fcm_notification.webpush_config == webpush_config
    assert fcm_notification.apns_config == nil
    assert fcm_notification.data == @data
  end

  test "notification with apns config" do
    apns_notification =
      APNSNotification.new("dummy device token")
      |> APNSNotification.add_title("apns title")
      |> APNSNotification.add_body("apns body")

    apns_config =
      APNSConfig.new("link", fn -> {"Authorization", "Bearer dummy token"} end)

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        @title,
        @body,
        :token,
        @target,
        @project_id,
        @data
      )
      |> Notification.add_apns_config(apns_config)

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android_config == nil
    assert fcm_notification.webpush_config == nil
    assert fcm_notification.apns_config == apns_config
    assert fcm_notification.data == @data
  end
end
