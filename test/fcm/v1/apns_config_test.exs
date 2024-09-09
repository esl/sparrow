defmodule Sparrow.FCM.V1.APNSTest do
  use ExUnit.Case

  alias Sparrow.APNS.Notification
  alias Sparrow.FCM.V1.APNS

  test "apns config is created correcly" do
    token_getter = fn -> {"authorization", "Bearer dummy token"} end

    apns_notification =
      "dummy device token"
      |> Notification.new(:dev)
      |> Notification.add_title("apns title")
      |> Notification.add_body("apns body")

    apns = APNS.new(apns_notification, token_getter)

    assert token_getter == apns.token_getter
    assert apns_notification == apns.notification
  end

  test "apns config is built correcly" do
    token_getter = fn -> {"authorization", "Bearer dummy token"} end

    apns_notification =
      "dummy device token"
      |> Notification.new(:dev)
      |> Notification.add_title("apns title")
      |> Notification.add_body("apns body")
      |> Notification.add_apns_id("apns id")

    apns_config =
      APNS.new(apns_notification, token_getter)
      |> APNS.to_map()

    assert %{headers: headers, payload: payload} = apns_config
    assert headers["apns-id"] == "apns id"
    assert headers["authorization"] == "Bearer dummy token"

    assert %{"aps" => %{"alert" => %{title: "apns title", body: "apns body"}}} ==
             payload
  end

  test "apns config is created correcly without token getter" do
    apns_notification =
      "dummy device token"
      |> Notification.new(:dev)
      |> Notification.add_title("apns title")
      |> Notification.add_body("apns body")

    apns = APNS.new(apns_notification)

    assert nil == apns.token_getter
    assert apns_notification == apns.notification
  end

  test "apns config is built correcly without token getter" do
    apns_notification =
      "dummy device token"
      |> Notification.new(:dev)
      |> Notification.add_title("apns title")
      |> Notification.add_body("apns body")
      |> Notification.add_apns_id("apns id")

    apns_config =
      APNS.new(apns_notification)
      |> APNS.to_map()

    assert %{headers: headers, payload: payload} = apns_config
    assert headers["apns-id"] == "apns id"
    assert headers["authorization"] == nil

    assert %{"aps" => %{"alert" => %{title: "apns title", body: "apns body"}}} ==
             payload
  end
end
