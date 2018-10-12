defmodule Sparrow.FCM.V1.NotificationTest do
  use ExUnit.Case

  alias Sparrow.APNS.Notification, as: APNSNotification
  alias Sparrow.FCM.V1.Android
  alias Sparrow.FCM.V1.APNS
  alias Sparrow.FCM.V1.Webpush
  alias Sparrow.FCM.V1.Notification

  @title "test title"
  @body "test body"
  @target "test target"
  @project_id "test project_id"
  @data %{:keyA => :valueA, :B => :b}

  test "notification without any config" do
    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        :token,
        @target,
        @project_id,
        @title,
        @body,
        @data
      )

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android == nil
    assert fcm_notification.webpush == nil
    assert fcm_notification.apns == nil
    assert fcm_notification.data == @data
  end

  test "notification default values are set correctly" do
    notification = Notification.new(:token, "dummy token", "project_id")

    assert notification.title == nil
    assert notification.body == nil
    assert notification.data == %{}
  end

  test "notification default values are set but to default value" do
    notification =
      Notification.new(:token, "dummy token", "project_id", nil, nil, %{})

    assert notification.title == nil
    assert notification.body == nil
    assert notification.data == %{}
  end

  test "notification non default values are set correctly" do
    notification =
      Notification.new(
        :token,
        "dummy token",
        "project_id",
        @title,
        @body,
        @data
      )

    assert notification.title == @title
    assert notification.body == @body
    assert notification.data == @data
  end

  test "notification with android config" do
    android =
      Android.new()
      |> Android.add_collapse_key("collapse_key")
      |> Android.add_color("color")

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        :token,
        @target,
        @project_id,
        nil,
        nil,
        @data
      )
      |> Notification.add_android(android)

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == nil
    assert fcm_notification.body == nil
    assert fcm_notification.target == @target
    assert fcm_notification.android == android
    assert fcm_notification.webpush == nil
    assert fcm_notification.apns == nil
    assert fcm_notification.data == @data
  end

  test "notification with webpush config" do
    webpush = Webpush.new("link")

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        :token,
        @target,
        @project_id,
        @title,
        @body,
        @data
      )
      |> Notification.add_webpush(webpush)

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android == nil
    assert fcm_notification.webpush == webpush
    assert fcm_notification.apns == nil
    assert fcm_notification.data == @data
  end

  test "notification with apns config" do
    apns_notification =
      "dummy device token"
      |> APNSNotification.new(:dev)
      |> APNSNotification.add_title("apns title")
      |> APNSNotification.add_body("apns body")

    apns =
      APNS.new(apns_notification, fn ->
        {"authorization", "Bearer dummy token"}
      end)

    fcm_notification =
      Sparrow.FCM.V1.Notification.new(
        :token,
        @target,
        @project_id,
        @title,
        @body,
        @data
      )
      |> Notification.add_apns(apns)

    assert fcm_notification.project_id == @project_id
    assert fcm_notification.title == @title
    assert fcm_notification.body == @body
    assert fcm_notification.target == @target
    assert fcm_notification.android == nil
    assert fcm_notification.webpush == nil
    assert fcm_notification.apns == apns
    assert fcm_notification.data == @data
  end
end
