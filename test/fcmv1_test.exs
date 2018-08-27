defmodule Sparrow.FCMV1Test do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.FCM.V1.Notification
  alias Sparrow.FCM.V1.AndroidConfig

  @fcm_mock_address "localhost"
  @title "test title"
  @subtitle "test subtitle"
  @body "test body"
  @pre_path "/v1/projects/"
  @post_path "/messages:send"
  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {@pre_path <> "EchoBodyHandler" <> @post_path,
            Helpers.CowboyHandlers.EchoBodyHandler, []},
           {@pre_path <> "HeaderToBodyEchoHandler" <> @post_path,
            Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    config =
      Setup.create_h2_worker_config(
        @fcm_mock_address,
        :ranch.get_port(cowboys_name)
      )

    worker_spec = Setup.child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name), worker_pid: worker_pid}
  end

  test "notification json contains android config", context do
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

    notification =
      (@pre_path <> "EchoBodyHandler" <> @post_path)
      |> Notification.new("title", "body", :token, "target", "EchoBodyHandler")
      |> Notification.add_android_config(config)

    # {:ok, {headers, body}} =
    Sparrow.FCMV1.push(context[:worker_pid], notification)

    # {:ok, response} = Jason.decode(body)
  end
end
