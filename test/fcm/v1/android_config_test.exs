defmodule Sparrow.FCM.V1.AndroidTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Android

  @collapse_key "colllapse key"
  @priority :NORMAL
  @ttl 1234
  @restricted "restricted package name"
  @data %{:keyA => :valueA, :keyB => :valueB}

  @title "the lord of the rings"
  @body "two towers"
  @icon "sauron.jpg"
  @color "green"
  @sound "tum tum tum"
  @tag_field "hobbit"
  @click_action "destroy gondor"
  @body_loc_key "armour"
  @body_loc_args "mithril"
  @title_loc_key "moria"
  @title_loc_args "barlog"

  test "android config field are added" do
    config =
      Android.new()
      |> Android.add_collapse_key(@collapse_key)
      |> Android.add_priority(@priority)
      |> Android.add_ttl(@ttl)
      |> Android.add_restricted_package_name(@restricted)
      |> Android.add_data(@data)

    assert {:collapse_key, @collapse_key} in config.fields
    assert {:priority, @priority} in config.fields
    assert {:ttl, Integer.to_string(@ttl) <> "s"} in config.fields
    assert {:restricted_package_name, @restricted} in config.fields
    assert {:data, @data} in config.fields
    assert Enum.empty?(config.notification.fields)
  end

  test "android notification field are added" do
    config =
      Android.new()
      |> Android.add_title(@title)
      |> Android.add_body(@body)
      |> Android.add_icon(@icon)
      |> Android.add_color(@color)
      |> Android.add_sound(@sound)
      |> Android.add_tag(@tag_field)
      |> Android.add_click_action(@click_action)
      |> Android.add_body_loc_key(@body_loc_key)
      |> Android.add_body_loc_args(@body_loc_args)
      |> Android.add_title_loc_key(@title_loc_key)
      |> Android.add_title_loc_args(@title_loc_args)

    assert {:title, @title} in config.notification.fields
    assert {:body, @body} in config.notification.fields
    assert {:icon, @icon} in config.notification.fields
    assert {:color, @color} in config.notification.fields
    assert {:sound, @sound} in config.notification.fields
    assert {:tag, @tag_field} in config.notification.fields
    assert {:click_action, @click_action} in config.notification.fields
    assert {:body_loc_key, @body_loc_key} in config.notification.fields
    assert {:"body_loc_args[]", @body_loc_args} in config.notification.fields
    assert {:title_loc_key, @title_loc_key} in config.notification.fields
    assert {:"title_loc_args[]", @title_loc_args} in config.notification.fields
    assert Enum.empty?(config.fields)
  end

  test "android config, unknown prioirty" do
    assert_raise FunctionClauseError, fn ->
      Android.new()
      |> Android.add_priority(:LOW)
    end
  end

  test "android config, sets HIGH prioirty" do
    config =
      Android.new()
      |> Android.add_priority(:HIGH)

    assert {:priority, :HIGH} in config.fields
    assert 1 == Enum.count(config.fields)
  end
end
