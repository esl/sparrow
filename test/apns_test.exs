defmodule Sparrow.APNSTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.APNS.Notification

  @apns_mock_address "localhost"
  @path "/3/device/"
  @title "test title"
  @subtitle "test subtitle"
  @body "test body"
  @pool_name :apns_pool_name

  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {@path <> "OkResponseHandler",
            Helpers.CowboyHandlers.OkResponseHandler, []},
           {@path <> "ErrorResponseHandler",
            Helpers.CowboyHandlers.ErrorResponseHandler, []},
           {@path <> "EchoBodyHandler", Helpers.CowboyHandlers.EchoBodyHandler,
            []},
           {@path <> "HeaderToBodyEchoHandler",
            Helpers.CowboyHandlers.HeaderToBodyEchoHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    config =
      Setup.create_h2_worker_config(
        @apns_mock_address,
        :ranch.get_port(cowboys_name)
      )

    Sparrow.H2Worker.Pool.Config.new(@pool_name, config)
    |> Sparrow.H2Worker.Pool.start_link()

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    :ok
  end

  test "sending request to APNS mock returning success" do
    notification =
      "OkResponseHandler"
      |> Notification.new()
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)

    {:ok, {headers, body}} = Sparrow.APNS.push(@pool_name, notification)

    result = Sparrow.APNS.process_response({:ok, {headers, body}})

    assert {":status", "200"} in headers
    assert "" == body
    assert {"content-length", "0"} in headers
    assert :ok == result
  end

  test "sending async request to APNS" do
    notification =
      "OkResponseHandler"
      |> Notification.new()
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)

    assert :ok ==
             Sparrow.APNS.push(
               @pool_name,
               notification,
               is_sync: false
             )
  end

  test "sending invalid request blocked" do
    notification = Notification.new("OkResponseHandler")

    assert {:error, :invalid_notification} ==
             Sparrow.APNS.push(@pool_name, notification)
  end

  test "sending request to APNS mock returning error, chcecking error parsing" do
    notification =
      "ErrorResponseHandler"
      |> Notification.new()
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)

    {:ok, {headers, body}} = Sparrow.APNS.push(@pool_name, notification)

    result = Sparrow.APNS.process_response({:ok, {headers, body}})

    assert {":status", "321"} in headers
    assert {:error, {321, "My error reason"}} == result
  end

  test "notification json contains options aps_dictionary" do
    sound = "sound of silence"
    badge = "badge123"
    content_available = "shure thing"
    category = "best of 80's"
    thread_id = "thread_id_some_value"

    notification =
      "EchoBodyHandler"
      |> Notification.new()
      |> Notification.add_title(@title)
      |> Notification.add_sound(sound)
      |> Notification.add_badge(badge)
      |> Notification.add_content_available(content_available)
      |> Notification.add_category(category)
      |> Notification.add_thread_id(thread_id)

    {:ok, {headers, body}} = Sparrow.APNS.push(@pool_name, notification)

    {:ok, response} = Jason.decode(body)
    aps_opts = Map.get(response, "aps")

    assert {":status", "200"} in headers
    assert sound == Map.get(aps_opts, "sound")
    assert badge == Map.get(aps_opts, "badge")
    assert content_available == Map.get(aps_opts, "content-available")
    assert category == Map.get(aps_opts, "category")
    assert thread_id == Map.get(aps_opts, "thread-id")
  end

  test "notification json contains options alert" do
    title_loc_key = "title_loc_key of some kind"
    title_loc_args = "args loc titile"
    subtitle_loc_key = "subtitle_loc_key of some kind"
    subtitle_loc_args = "subargs loc titile"
    loc_args = " arg1 arg2"
    launch_image = "image lanch"
    loc_key = "loc_key value"
    action_loc_key = "my test action loc key"

    notification =
      "EchoBodyHandler"
      |> Notification.new()
      |> Notification.add_title(@title)
      |> Notification.add_subtitle(@subtitle)
      |> Notification.add_body(@body)
      |> Notification.add_title_loc_key(title_loc_key)
      |> Notification.add_title_loc_args(title_loc_args)
      |> Notification.add_subtitle_loc_key(subtitle_loc_key)
      |> Notification.add_subtitle_loc_args(subtitle_loc_args)
      |> Notification.add_loc_args(loc_args)
      |> Notification.add_launch_image(launch_image)
      |> Notification.add_loc_key(loc_key)
      |> Notification.add_action_loc_key(action_loc_key)

    {:ok, {headers, body}} = Sparrow.APNS.push(@pool_name, notification)

    {:ok, response} = Jason.decode(body)
    alert = Map.get(response, "aps")
    alert_content = Map.get(alert, "alert")

    assert {":status", "200"} in headers

    assert is_map(alert)
    assert is_map(alert_content)
    assert @title == Map.get(alert_content, "title")
    assert @subtitle == Map.get(alert_content, "subtitle")
    assert @body == Map.get(alert_content, "body")
    assert loc_key == Map.get(alert_content, "loc-key")
    assert title_loc_key == Map.get(alert_content, "title-loc-key")
    assert title_loc_args == Map.get(alert_content, "title-loc-args")
    assert subtitle_loc_key == Map.get(alert_content, "subtitle-loc-key")
    assert subtitle_loc_args == Map.get(alert_content, "subtitle-loc-args")
    assert loc_args == Map.get(alert_content, "loc-args")
    assert launch_image == Map.get(alert_content, "launch-image")
    assert loc_key == Map.get(alert_content, "loc-key")
    assert action_loc_key == Map.get(alert_content, "action-loc-key")
  end

  test "notification headers contain added headers" do
    notification =
      "HeaderToBodyEchoHandler"
      |> Notification.new()
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_expiration("apns expiration header value")
      |> Notification.add_apns_id("apns id value")
      |> Notification.add_apns_priority("apns priority value")
      |> Notification.add_apns_topic("apns topic value")
      |> Notification.add_apns_collapse_id("apns collapse id value")

    {:ok, {response_headers, body}} =
      Sparrow.APNS.push(@pool_name, notification)

    {response_headers_map, _} = Code.eval_string(body)
    headers_decoded_from_body = Map.to_list(response_headers_map)

    assert {":status", "200"} in response_headers
    assert {"content-type", "application/json"} in headers_decoded_from_body
    assert {"accept", "application/json"} in headers_decoded_from_body

    assert {"apns-expiration", "apns expiration header value"} in headers_decoded_from_body

    assert {"apns-id", "apns id value"} in headers_decoded_from_body
    assert {"apns-priority", "apns priority value"} in headers_decoded_from_body
    assert {"apns-topic", "apns topic value"} in headers_decoded_from_body

    assert {"apns-collapse-id", "apns collapse id value"} in headers_decoded_from_body
  end

  test "notification custom data" do
    notification =
      "EchoBodyHandler"
      |> Notification.new()
      |> Notification.add_title("Game Request")
      |> Notification.add_custom_data("gameID", "12345678")

    {:ok, {_headers, body}} = Sparrow.APNS.push(@pool_name, notification)

    {:ok, response} = Jason.decode(body)
    assert "12345678" == Map.get(response, "gameID")
  end

  test "notification apns example based all levels test" do
    notification =
      "EchoBodyHandler"
      |> Notification.new()
      |> Notification.add_title("Game Request")
      |> Notification.add_subtitle("Five Card Draw")
      |> Notification.add_body("Bob wants to play poker")
      |> Notification.add_category("GAME_INVITATION")
      |> Notification.add_custom_data("gameID", "12345678")

    {:ok, {_headers, body}} = Sparrow.APNS.push(@pool_name, notification)

    {:ok, response} = Jason.decode(body)

    expected_response =
      "{\"aps\":
        {\"alert\":
          { \"title\":\"Game Request\",
            \"subtitle\":\"Five Card Draw\",
            \"body\":\"Bob wants to play poker\"
          },
          \"category\":\"GAME_INVITATION\"
        },
        \"gameID\" : \"12345678\"
      }"
      |> Jason.decode!()

    assert expected_response == response
  end

  @key_id "KEYID"
  @team_id "TEAMID"
  @p8_file_path "token.p8"

  test "APNS token based config is biuld correctly" do
    {:ok, _pid} =
      %{:token_id => Sparrow.APNS.Token.new(@key_id, @team_id, @p8_file_path)}
      |> Sparrow.APNS.TokenBearer.init()

    auth = Sparrow.APNS.get_token_based_authentication(:token_id)

    config =
      auth
      |> Sparrow.APNS.get_h2worker_config()

    {header_key, header_value} = auth.token_getter.()
    assert header_key == "authorization"
    assert header_value =~ "bearer"
    assert config.domain == "api.development.push.apple.com"
    assert config.port == 443
    assert config.tls_options == []
    assert config.ping_interval == 5000
    assert config.reconnect_attempts == 3
    assert config.authentication == auth
  end

  test "APNS certificate based config is biuld correctly" do
    path_to_cert = "path/to/cert"
    path_to_key = "path/to/key"

    auth =
      Sparrow.APNS.get_certificate_based_authentication(
        path_to_cert,
        path_to_key
      )

    config =
      auth
      |> Sparrow.APNS.get_h2worker_config()

    assert config.domain == "api.development.push.apple.com"
    assert config.port == 443
    assert config.tls_options == []
    assert config.ping_interval == 5000
    assert config.reconnect_attempts == 3
    assert config.authentication == auth
    assert auth.certfile == path_to_cert
    assert auth.keyfile == path_to_key
  end
end
