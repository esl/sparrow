defmodule Sparrow.FCM.V1.Test do
  use ExUnit.Case

  alias Sparrow.FCM.V1.AndroidConfig

  test "android config field are added" do
    collapse_key = "colllapse key"
    priority = :NORMAL
    ttl = "some ttl"
    restricted = "restricted package name"
    data = %{:keyA => :valueA, :keyB => :valueB}

    config =
      AndroidConfig.new()
      |> AndroidConfig.add_collapse_key(collapse_key)
      |> AndroidConfig.add_priority(priority)
      |> AndroidConfig.add_ttl(ttl)
      |> AndroidConfig.add_restricted_package_name(restricted)
      |> AndroidConfig.add_data(data)

    assert {:collapse_key, collapse_key} in config.fields
    assert {:priority, priority} in config.fields
    assert {:ttl, ttl} in config.fields
    assert {:restricted_package_name, restricted} in config.fields
    assert {:data, data} in config.fields
  end

  test "android notification field are added" do
    title = "the lord of the rings"
    body = "two towers"
    icon = "sauron.jpg"
    color = "green"
    sound = "tum tum tum"
    tag = "#hobbit"
    click_action = "destroy gondor"
    body_loc_key = "armour"
    body_loc_args = "mithril"
    title_loc_key = "moria"
    title_loc_args = "barlog"

    config =
      AndroidConfig.new()
      |> AndroidConfig.add_title(title)
      |> AndroidConfig.add_body(body)
      |> AndroidConfig.add_icon(icon)
      |> AndroidConfig.add_color(color)
      |> AndroidConfig.add_sound(sound)
      |> AndroidConfig.add_tag(tag)
      |> AndroidConfig.add_click_action(click_action)
      |> AndroidConfig.add_body_loc_key(body_loc_key)
      |> AndroidConfig.add_body_loc_args(body_loc_args)
      |> AndroidConfig.add_title_loc_key(title_loc_key)
      |> AndroidConfig.add_title_loc_args(title_loc_args)

    assert {:title, title} in config.notification.fields
    assert {:body, body} in config.notification.fields
    assert {:icon, icon} in config.notification.fields
    assert {:color, color} in config.notification.fields
    assert {:sound, sound} in config.notification.fields
    assert {:tag, tag} in config.notification.fields
    assert {:click_action, click_action} in config.notification.fields
    assert {:body_loc_key, body_loc_key} in config.notification.fields
    assert {:"body_loc_args[]", body_loc_args} in config.notification.fields
    assert {:title_loc_key, title_loc_key} in config.notification.fields
    assert {:"title_loc_args[]", title_loc_args} in config.notification.fields
  end

  test "android config, unknown prioirty" do
    assert_raise FunctionClauseError, fn ->
      AndroidConfig.new()
      |> AndroidConfig.add_priority(:LOW)
    end
  end
end
