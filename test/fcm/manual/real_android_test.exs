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
    Sparrow.FCM.V1.TokenBearer.start_link(@path_to_json)

    {:ok, _pid} = Sparrow.PoolsWarden.start_link()

    worker_config =
      Sparrow.FCM.V1.get_token_based_authentication()
      |> Sparrow.FCM.V1.get_h2worker_config()

    {:ok, _pid} =
      Sparrow.H2Worker.Pool.Config.new(worker_config)
      |> Sparrow.H2Worker.Pool.start_link(:fcm, [:webpush])

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

    notification
    |> Sparrow.API.push([:webpush])
    |> IO.inspect()
  end
end
