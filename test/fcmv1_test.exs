defmodule Sparrow.FCMV1Test do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.FCM.V1.Notification
  alias Sparrow.FCM.V1.AndroidConfig
  alias Sparrow.FCM.V1.WebpushConfig
  alias Sparrow.FCM.V1.APNSConfig

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
  @android_ttl "android test ttl"

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

    worker_spec = Setup.child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name), worker_pid: worker_pid}
  end

  test "empty notification is build and sent", context do
    notification = test_notification("EchoBodyHandler")

    {:ok, {_headers, body}} =
      Sparrow.FCMV1.push(context[:worker_pid], notification)

    actual_decoded_notification = body |> Jason.decode!()

    assert @notification_data == Map.get(actual_decoded_notification, "data")
  end

  test "notification with android config is build and sent", context do
    notification =
      test_notification("EchoBodyHandler")
      |> Notification.add_android_config(test_android_config())

    {:ok, {_headers, body}} =
      Sparrow.FCMV1.push(context[:worker_pid], notification)

    actual_decoded_android_config =
      body |> Jason.decode!() |> Map.get("android")

    actual_decoded_android_notification =
      Map.get(actual_decoded_android_config, "notification")

    assert actual_decoded_android_config != nil
    assert @android_data == Map.get(actual_decoded_android_config, "data")

    assert @android_collapse_key ==
             Map.get(actual_decoded_android_config, "collapse_key")

    assert @android_body == Map.get(actual_decoded_android_notification, "body")

    assert @android_title ==
             Map.get(actual_decoded_android_notification, "title")
  end

  test "notification with webpush config is build and sent", context do
    notification =
      test_notification("EchoBodyHandler")
      |> Notification.add_webpush_config(test_webpush_config())

    {:ok, {_headers, body}} =
      Sparrow.FCMV1.push(context[:worker_pid], notification)

    actual_decoded_webpush_config =
      body |> Jason.decode!() |> Map.get("webpush")

    actual_decoded_webpush_notification =
      Map.get(actual_decoded_webpush_config, "notification")

    assert actual_decoded_webpush_config != nil
    assert @webpush_data == Map.get(actual_decoded_webpush_config, "data")
    assert @webpush_body == Map.get(actual_decoded_webpush_notification, "body")

    assert @webpush_title ==
             Map.get(actual_decoded_webpush_notification, "title")
  end

  test "notification with apns config is build and sent", context do
    notification =
      test_notification("EchoBodyHandler")
      |> Notification.add_apns_config(test_apns_config())

    {:ok, {_headers, body}} =
      Sparrow.FCMV1.push(context[:worker_pid], notification)

    actual_decoded_apns_config = body |> Jason.decode!() |> Map.get("apns")

    actual_decoded_apns_payload = Map.get(actual_decoded_apns_config, "payload")

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

  defp test_notification(project_id) do
    Notification.new(
      @notification_title,
      @notification_body,
      @notification_target_type,
      @notification_target,
      project_id,
      @notification_data
    )
  end

  defp test_android_config do
    AndroidConfig.new()
    |> AndroidConfig.add_body(@android_body)
    |> AndroidConfig.add_body_loc_args(@android_body_loc_args)
    |> AndroidConfig.add_body_loc_key(@android_body_loc_key)
    |> AndroidConfig.add_click_action(@android_click_action)
    |> AndroidConfig.add_collapse_key(@android_collapse_key)
    |> AndroidConfig.add_color(@android_color)
    |> AndroidConfig.add_data(@android_data)
    |> AndroidConfig.add_icon(@android_icon)
    |> AndroidConfig.add_priority(@android_priority)
    |> AndroidConfig.add_restricted_package_name(
      @android_restricted_package_name
    )
    |> AndroidConfig.add_sound(@android_sound)
    |> AndroidConfig.add_tag(@android_tag)
    |> AndroidConfig.add_title(@android_title)
    |> AndroidConfig.add_title_loc_args(@android_title_loc_args)
    |> AndroidConfig.add_title_loc_key(@android_title_loc_key)
    |> AndroidConfig.add_ttl(@android_ttl)
  end

  defp test_webpush_config do
    WebpushConfig.new(@webpush_link, @webpush_data)
    |> WebpushConfig.add_actions(@webpush_actions)
    |> WebpushConfig.add_badge(@webpush_badge)
    |> WebpushConfig.add_body(@webpush_body)
    |> WebpushConfig.add_dir(@webpush_dir)
    |> WebpushConfig.add_header(@webpush_header_key, @webpush_header_value)
    |> WebpushConfig.add_icon(@webpush_icon)
    |> WebpushConfig.add_image(@webpush_image)
    |> WebpushConfig.add_lang(@webpush_lang)
    |> WebpushConfig.add_permission(@webpush_permission)
    |> WebpushConfig.add_renotify(@webpush_renotify)
    |> WebpushConfig.add_requireInteraction(@webpush_requireInteraction)
    |> WebpushConfig.add_silent(@webpush_silent)
    |> WebpushConfig.add_tag(@webpush_tag)
    |> WebpushConfig.add_timestamp(@webpush_timestamp)
    |> WebpushConfig.add_title(@webpush_title)
    |> WebpushConfig.add_vibrate(@webpush_vibrate)
    |> WebpushConfig.add_web_notification_data(@webpush_web_notification_data)
  end

  defp test_apns_config do
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

    APNSConfig.new(apns_notiifcation, fn ->
      {"authorization", "dummy apns token"}
    end)
  end
end
