defmodule Sparrow.FCM.V1Test do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.FCM.V1.Notification
  alias Sparrow.FCM.V1.Android
  alias Sparrow.FCM.V1.Webpush
  alias Sparrow.FCM.V1.APNS

  @fcm_mock_address "localhost"

  @notification_title "fcm notification title"
  @notification_body "fcm notification body"
  @notification_target_type :token
  @notification_target "target"
  @notification_data %{"notification" => "some_value", "key" => "other_value"}

  @apns_title "test apns title"
  @apns_body "test apns body"
  @apns_custom_data_key "apns test custom data key"
  @apns_custom_data_value "apns test custom data value"
  @apns_sound "tum tu rum tum"
  @apns_badge "apns test badge"

  @webpush_link "webpush test link"
  @webpush_data %{"webpush" => "data", "test" => "value"}
  @webpush_actions "webpush test actions"
  @webpush_badge "webpush test badge"
  @webpush_body "webpush test body"
  @webpush_dir "webpush test dir"
  @webpush_header_key "webpush test header_key"
  @webpush_header_value "webpush test header_value"
  @webpush_icon "webpush test icon"
  @webpush_image "webpush test image"
  @webpush_lang "webpush test lang"
  @webpush_permission :granted
  @webpush_renotify "webpush test renotify"
  @webpush_requireInteraction true
  @webpush_silent "webpush test silent"
  @webpush_tag "webpush test tag"
  @webpush_timestamp "webpush test timestamp"
  @webpush_title "webpush test title"
  @webpush_vibrate "webpush test vibrate"
  @webpush_web_notification_data "webpush test web_notification_data"

  @android_body "android test body"
  @android_body_loc_args "android test body_loc_args"
  @android_body_loc_key "android test body_loc_key"
  @android_click_action "android test click_action"
  @android_collapse_key "android test collapse_key"
  @android_color "android test color"
  @android_data %{"android" => "is_key", "test" => "data"}
  @android_icon "android test icon"
  @android_priority :HIGH
  @android_restricted_package_name "android test restricted_package_name"
  @android_sound "android test sound"
  @android_tag "android test tag"
  @android_title "android test title"
  @android_title_loc_args "android test title_loc_args"
  @android_title_loc_key "android test title_loc_key"
  @android_ttl 4321

  @pool_name :name
  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/v1/projects/EchoBodyHandler/messages:send",
            Helpers.CowboyHandlers.EchoBodyHandler, []},
           {"/v1/projects/HeaderToBodyEchoHandler/messages:send",
            Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    config =
      Setup.create_h2_worker_config(
        @fcm_mock_address,
        :ranch.get_port(cowboys_name),
        :token_based
      )

    Sparrow.H2Worker.Pool.Config.new(@pool_name, config)
    |> Sparrow.H2Worker.Pool.start_link()

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  test "empty notification is built and sent" do
    notification = test_notification("EchoBodyHandler")

    {:ok, {_headers, body}} = Sparrow.FCM.V1.push(@pool_name, notification)

    actual_decoded_notification =
      body
      |> Jason.decode!()
      |> Map.get("message")

    assert @notification_data == Map.get(actual_decoded_notification, "data")
  end

  test "android notification is built and sent" do
    notification =
      test_notification("EchoBodyHandler")
      |> Notification.add_android(test_android())

    {:ok, {_headers, body}} = Sparrow.FCM.V1.push(@pool_name, notification)

    actual_decoded_android =
      body
      |> Jason.decode!()
      |> Map.get("message")
      |> Map.get("android")

    actual_decoded_android_notification =
      Map.get(actual_decoded_android, "notification")

    assert actual_decoded_android != nil
    assert @android_data == Map.get(actual_decoded_android, "data")

    assert @android_collapse_key ==
             Map.get(actual_decoded_android, "collapse_key")

    expected_ttl = Integer.to_string(@android_ttl) <> "s"
    assert expected_ttl == Map.get(actual_decoded_android, "ttl")

    assert @android_body == Map.get(actual_decoded_android_notification, "body")

    assert @android_title ==
             Map.get(actual_decoded_android_notification, "title")
  end

  test "webpush notification is built and sent" do
    notification =
      test_notification("EchoBodyHandler")
      |> Notification.add_webpush(test_webpush())

    {:ok, {_headers, body}} = Sparrow.FCM.V1.push(@pool_name, notification)

    actual_decoded_webpush =
      body
      |> Jason.decode!()
      |> Map.get("message")
      |> Map.get("webpush")

    actual_decoded_webpush_notification =
      Map.get(actual_decoded_webpush, "notification")

    assert actual_decoded_webpush != nil
    assert @webpush_data == Map.get(actual_decoded_webpush, "data")
    assert @webpush_body == Map.get(actual_decoded_webpush_notification, "body")

    assert @webpush_title ==
             Map.get(actual_decoded_webpush_notification, "title")
  end

  test "apns notification is built and sent" do
    notification =
      test_notification_without_optional_args("EchoBodyHandler")
      |> Notification.add_apns(test_apns())

    {:ok, {_headers, body}} = Sparrow.FCM.V1.push(@pool_name, notification)

    actual_decoded_apns =
      body
      |> Jason.decode!()
      |> Map.get("message")
      |> Map.get("apns")

    actual_decoded_apns_payload = Map.get(actual_decoded_apns, "payload")

    aps_dictionary = Map.get(actual_decoded_apns_payload, "aps")
    alert_dictionary = Map.get(aps_dictionary, "alert")

    assert actual_decoded_apns_payload != nil

    assert @apns_custom_data_value ==
             Map.get(actual_decoded_apns_payload, @apns_custom_data_key)

    assert @apns_badge == Map.get(aps_dictionary, "badge")
    assert @apns_sound == Map.get(aps_dictionary, "sound")

    assert @apns_title == Map.get(alert_dictionary, "title")
    assert @apns_body == Map.get(alert_dictionary, "body")
  end

  test "FCm token based config is biuld correctly" do
    {:ok, _pid} = Sparrow.FCM.V1.TokenBearer.start_link("./sparrow_token.json")

    auth = Sparrow.FCM.V1.get_token_based_authentication()

    config =
      auth
      |> Sparrow.FCM.V1.get_h2worker_config()

    assert config.domain == "fcm.googleapis.com"
    assert config.port == 443
    assert config.tls_options == []
    assert config.ping_interval == 5000
    assert config.reconnect_attempts == 3
    assert config.authentication == auth
  end

  defp test_notification(project_id) do
    Notification.new(
      @notification_target_type,
      @notification_target,
      project_id,
      @notification_title,
      @notification_body,
      @notification_data
    )
  end

  defp test_notification_without_optional_args(project_id) do
    Notification.new(
      @notification_target_type,
      @notification_target,
      project_id
    )
  end

  defp test_android do
    Android.new()
    |> Android.add_body(@android_body)
    |> Android.add_body_loc_args(@android_body_loc_args)
    |> Android.add_body_loc_key(@android_body_loc_key)
    |> Android.add_click_action(@android_click_action)
    |> Android.add_collapse_key(@android_collapse_key)
    |> Android.add_color(@android_color)
    |> Android.add_data(@android_data)
    |> Android.add_icon(@android_icon)
    |> Android.add_priority(@android_priority)
    |> Android.add_restricted_package_name(@android_restricted_package_name)
    |> Android.add_sound(@android_sound)
    |> Android.add_tag(@android_tag)
    |> Android.add_title(@android_title)
    |> Android.add_title_loc_args(@android_title_loc_args)
    |> Android.add_title_loc_key(@android_title_loc_key)
    |> Android.add_ttl(@android_ttl)
  end

  defp test_webpush do
    Webpush.new(@webpush_link, @webpush_data)
    |> Webpush.add_actions(@webpush_actions)
    |> Webpush.add_badge(@webpush_badge)
    |> Webpush.add_body(@webpush_body)
    |> Webpush.add_dir(@webpush_dir)
    |> Webpush.add_header(@webpush_header_key, @webpush_header_value)
    |> Webpush.add_icon(@webpush_icon)
    |> Webpush.add_image(@webpush_image)
    |> Webpush.add_lang(@webpush_lang)
    |> Webpush.add_permission(@webpush_permission)
    |> Webpush.add_renotify(@webpush_renotify)
    |> Webpush.add_requireInteraction(@webpush_requireInteraction)
    |> Webpush.add_silent(@webpush_silent)
    |> Webpush.add_tag(@webpush_tag)
    |> Webpush.add_timestamp(@webpush_timestamp)
    |> Webpush.add_title(@webpush_title)
    |> Webpush.add_vibrate(@webpush_vibrate)
    |> Webpush.add_web_notification_data(@webpush_web_notification_data)
  end

  defp test_apns do
    apns_notiifcation =
      "dummy_device_token"
      |> Sparrow.APNS.Notification.new()
      |> Sparrow.APNS.Notification.add_title(@apns_title)
      |> Sparrow.APNS.Notification.add_body(@apns_body)
      |> Sparrow.APNS.Notification.add_custom_data(
        @apns_custom_data_key,
        @apns_custom_data_value
      )
      |> Sparrow.APNS.Notification.add_sound(@apns_sound)
      |> Sparrow.APNS.Notification.add_badge(@apns_badge)

    APNS.new(apns_notiifcation, fn ->
      {"authorization", "dummy apns token"}
    end)
  end
end
