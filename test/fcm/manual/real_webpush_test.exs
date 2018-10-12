defmodule Sparrow.FCM.Manual.RealWebpushTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Notification

  @project_id "sparrow-2b961"
  @webpush_title "TORA"
  @webpush_body "TORA TORA"
  # get token from browser
  @webpush_target_type :token
  @webpush_target "dummy"
  @path_to_json "priv/fcm/token/sparrow_token.json"

  @tag :skip
  test "real webpush notification send" do
    fcm = [
      [
        path_to_json: @path_to_json
      ]
    ]

    Application.stop(:sparrow)
    Application.put_env(:sparrow, :fcm, fcm)
    Application.start(:sparrow)

    webpush =
      Sparrow.FCM.V1.Webpush.new("www.google.com")
      |> Sparrow.FCM.V1.Webpush.add_title(@webpush_title)
      |> Sparrow.FCM.V1.Webpush.add_body(@webpush_body)

    notification =
      @webpush_target_type
      |> Notification.new(
        @webpush_target,
        @project_id
      )
      |> Notification.add_webpush(webpush)

    :ok = Sparrow.API.push(notification)
  end
end
