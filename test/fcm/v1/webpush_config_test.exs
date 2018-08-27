defmodule Sparrow.FCM.V1.WebpushConfigTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.WebpushConfig

  @link "test link"
  @web_push_data %{:key1 => :value1, :key2 => :value2}
  @web_notification_data %{:keyA => :valueA, :keyB => :valueB}
  @header_key "header_key"
  @header_value "header_value"

  test "webpush config is build correcly" do
    actions = "test actions"
    badge = "test badge"
    body = "test body"
    dir = "test dir"
    lang = "test lang"
    tag = "test tag"
    icon = "test icon"
    image = "test image"
    renotify = "test renotify"
    silent = "test silent"
    timestamp = "test time"
    title = "test title"
    vibrate = "test vibrate"

    webpush_config =
      WebpushConfig.new(@link, @data)
      |> WebpushConfig.add_header(@header_key, @header_value)
      |> WebpushConfig.add_web_push_data(@web_push_data)
      |> WebpushConfig.add_web_notification_data(@web_notification_data)
      |> WebpushConfig.add_permission(:granted)
      |> WebpushConfig.add_actions(actions)
      |> WebpushConfig.add_badge(badge)
      |> WebpushConfig.add_body(body)
      |> WebpushConfig.add_dir(dir)
      |> WebpushConfig.add_lang(lang)
      |> WebpushConfig.add_tag(tag)
      |> WebpushConfig.add_icon(icon)
      |> WebpushConfig.add_image(image)
      |> WebpushConfig.add_renotify(renotify)
      |> WebpushConfig.add_requireInteraction(true)
      |> WebpushConfig.add_silent(silent)
      |> WebpushConfig.add_timestamp(timestamp)
      |> WebpushConfig.add_title(title)
      |> WebpushConfig.add_vibrate(vibrate)

    assert [{@header_key, @header_value}] == webpush_config.headers
    assert {:permission, :granted} in webpush_config.web_notification.fields
    assert {:actions, actions} in webpush_config.web_notification.fields
    assert {:badge, badge} in webpush_config.web_notification.fields
    assert {:body, body} in webpush_config.web_notification.fields
    assert {:dir, dir} in webpush_config.web_notification.fields
    assert {:lang, lang} in webpush_config.web_notification.fields
    assert {:tag, tag} in webpush_config.web_notification.fields
    assert {:icon, icon} in webpush_config.web_notification.fields
    assert {:image, image} in webpush_config.web_notification.fields
    assert {:renotify, renotify} in webpush_config.web_notification.fields
    assert {:silent, silent} in webpush_config.web_notification.fields
    assert {:timestamp, timestamp} in webpush_config.web_notification.fields
    assert {:title, title} in webpush_config.web_notification.fields
    assert {:vibrate, vibrate} in webpush_config.web_notification.fields
    assert @web_push_data == webpush_config.data
  end
end
