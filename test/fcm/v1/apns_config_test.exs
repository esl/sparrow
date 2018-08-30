defmodule Sparrow.FCM.V1.APNSConfigTest do
  use ExUnit.Case

  alias Sparrow.APNS.Notification
  alias Sparrow.FCM.V1.APNSConfig

  test "apns config is build correcly" do
    token_getter = fn -> {"Authorization", "Bearer dummy token"} end

    apns_notification =
      Notification.new("dummy device token")
      |> Notification.add_title("apns title")
      |> Notification.add_body("apns body")

    apns_config = APNSConfig.new(apns_notification, token_getter)

    assert token_getter == apns_config.token_getter
    assert apns_notification == apns_config.notification
  end
end
