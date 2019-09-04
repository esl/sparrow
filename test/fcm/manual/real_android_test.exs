defmodule Sparrow.FCM.Manual.RealAndroidTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Notification

  @project_id "sparrow-2b961"
  @target_type :topic
  @target "news"

  @notification_title "Commander Cody"
  @notification_body "the time has come. Execute order 66."

  @android_title "Real life"
  @android_body "never heard of that server"
  @path_to_json "priv/fcm/token/sparrow_token.json"

  @tag :skip
  test "real android notification send" do
    fcm = [
      [
        path_to_json: @path_to_json
      ]
    ]

    start_sparrow_with_fcm_config(fcm)

    android =
      Sparrow.FCM.V1.Android.new()
      |> Sparrow.FCM.V1.Android.add_title(@android_title)
      |> Sparrow.FCM.V1.Android.add_body(@android_body)

    notification =
      @target_type
      |> Notification.new(
        @target,
        @project_id,
        @notification_title,
        @notification_body
      )
      |> Notification.add_android(android)

    assert :ok == Sparrow.API.push(notification)
    TestHelper.restore_app_env()
  end

  defp start_sparrow_with_fcm_config(config) do
    Application.stop(:sparrow)
    Application.put_env(:sparrow, :fcm, config)
    Application.start(:sparrow)
  end
end
