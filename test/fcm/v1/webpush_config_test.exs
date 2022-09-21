defmodule Sparrow.FCM.V1.WebpushTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Webpush

  @link "test link"
  @web_push_data %{:key1 => :value1, :key2 => :value2}
  @web_notification_data %{:keyA => :valueA, :keyB => :valueB}
  @header_key "header_key"
  @header_value "header_value"

  test "webpush config is built correcly" do
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

    webpush =
      Webpush.new(@link, @web_push_data)
      |> Webpush.add_header(@header_key, @header_value)
      |> Webpush.add_web_notification_data(@web_notification_data)
      |> Webpush.add_permission(:granted)
      |> Webpush.add_actions(actions)
      |> Webpush.add_badge(badge)
      |> Webpush.add_body(body)
      |> Webpush.add_dir(dir)
      |> Webpush.add_lang(lang)
      |> Webpush.add_tag(tag)
      |> Webpush.add_icon(icon)
      |> Webpush.add_image(image)
      |> Webpush.add_renotify(renotify)
      |> Webpush.add_require_interaction(true)
      |> Webpush.add_silent(silent)
      |> Webpush.add_timestamp(timestamp)
      |> Webpush.add_title(title)
      |> Webpush.add_vibrate(vibrate)

    assert [{@header_key, @header_value}] == webpush.headers
    assert {:permission, :granted} in webpush.web_notification.fields
    assert {:actions, actions} in webpush.web_notification.fields
    assert {:badge, badge} in webpush.web_notification.fields
    assert {:body, body} in webpush.web_notification.fields
    assert {:dir, dir} in webpush.web_notification.fields
    assert {:lang, lang} in webpush.web_notification.fields
    assert {:tag, tag} in webpush.web_notification.fields
    assert {:icon, icon} in webpush.web_notification.fields
    assert {:image, image} in webpush.web_notification.fields
    assert {:renotify, renotify} in webpush.web_notification.fields
    assert {:silent, silent} in webpush.web_notification.fields
    assert {:timestamp, timestamp} in webpush.web_notification.fields
    assert {:title, title} in webpush.web_notification.fields
    assert {:vibrate, vibrate} in webpush.web_notification.fields
    assert @web_push_data == webpush.data
  end
end
