defmodule Sparrow.APNSTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.APNS.Notification

  @apns_mock_address "localhost"
  @path "/3/device/"
  @provider_token "test_provider_token"
  @title "test title"
  @body "test body"

  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {@path <> "OkResponseHandler", Helpers.CowboyHandlers.OkResponseHandler, []},
           {@path <> "ErrorResponseHandler", Helpers.CowboyHandlers.ErrorResponseHandler, []},
           {@path <> "EchoBodyHandler", Helpers.CowboyHandlers.EchoBodyHandler, []},
           {@path <> "HeaderToBodyEchoHandler", Helpers.CowboyHandlers.HeaderToBodyEchoHandler,
            []}
         ]}
      ])
      |> Setup.start_cowboy_tls(certificate_required: :no)

    config = Setup.create_h2_worker_config(@apns_mock_address, :ranch.get_port(cowboys_name))
    worker_spec = Setup.child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name), worker_pid: worker_pid}
  end

  test "sending request to APNS mock returning success", context do
    notification =
      Notification.new("OkResponseHandler")
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)

    {:ok, {headers, body}} = Sparrow.APNS.push(context[:worker_pid], notification)
    result = Sparrow.APNS.process_response({:ok, {headers, body}})

    assert {":status", "200"} in headers
    assert "" == body
    assert {"content-length", "0"} in headers
    assert :ok == result
  end

  test "sending async request to APNS", context do
    notification =
      Notification.new("OkResponseHandler")
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)

    assert :ok == Sparrow.APNS.push(context[:worker_pid], notification, is_sync: false)
  end

  test "sending request to APNS mock returning error, chcecking error parsing", context do
    notification =
      Notification.new("ErrorResponseHandler")
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)

    {:ok, {headers, body}} = Sparrow.APNS.push(context[:worker_pid], notification)
    result = Sparrow.APNS.process_response({:ok, {headers, body}})

    assert {":status", "321"} in headers
    assert {:error, {321, "My error reason"}} == result
  end

  test "notification json contains options aps_dictionary", context do
    sound = "sound of silence"
    badge = "badge123"
    content_available = "shure thing"
    category = "best of 80's"
    thread_id = "thread_id_some_value"

    notification =
      Notification.new("EchoBodyHandler")
      |> Notification.add_sound(sound)
      |> Notification.add_badge(badge)
      |> Notification.add_content_available(content_available)
      |> Notification.add_category(category)
      |> Notification.add_thread_id(thread_id)

    {:ok, {headers, body}} = Sparrow.APNS.push(context[:worker_pid], notification)
    {:ok, response} = Jason.decode(body)

    assert {":status", "200"} in headers
    assert sound == Map.get(response, "sound")
    assert badge == Map.get(response, "badge")
    assert content_available == Map.get(response, "content-available")
    assert category == Map.get(response, "category")
    assert thread_id == Map.get(response, "thread-id")
  end

  test "notification json contains options alert", context do
    title_loc_key = "title_loc_key of some kind"
    title_loc_args = "args loc titile"
    loc_args = " arg1 arg2"
    launch_image = "image lanch"
    loc_key = "loc_key value"
    action_loc_key = "my test action loc key"

    notification =
      Notification.new("EchoBodyHandler")
      |> Notification.add_title_loc_key(title_loc_key)
      |> Notification.add_title_loc_args(title_loc_args)
      |> Notification.add_loc_args(loc_args)
      |> Notification.add_launch_image(launch_image)
      |> Notification.add_loc_key(loc_key)
      |> Notification.add_action_loc_key(action_loc_key)

    {:ok, {headers, body}} = Sparrow.APNS.push(context[:worker_pid], notification)
    {:ok, response} = Jason.decode(body)
    alert = Map.get(response, "aps")
    alert_content = Map.get(alert, "alert")

    assert {":status", "200"} in headers

    assert is_map(alert)
    assert is_map(alert_content)
    assert loc_key == Map.get(alert_content, "loc-key")
    assert title_loc_key == Map.get(alert_content, "title-loc-key")
    assert title_loc_args == Map.get(alert_content, "title-loc-args")
    assert loc_args == Map.get(alert_content, "loc-args")
    assert launch_image == Map.get(alert_content, "launch-image")
    assert loc_key == Map.get(alert_content, "loc-key")
    assert action_loc_key == Map.get(alert_content, "action-loc-key")
  end

  test "notification headers contain added headers", context do
    notification =
      Notification.new("HeaderToBodyEchoHandler")
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_expiration("apns expiration header value")
      |> Notification.add_apns_id("apns id value")
      |> Notification.add_apns_priority("apns priority value")
      |> Notification.add_apns_topic("apns topic value")
      |> Notification.add_apns_collapse_id("apns collapse id value")
      |> Notification.add_authorization(@provider_token)

    {:ok, {response_headers, body}} = Sparrow.APNS.push(context[:worker_pid], notification)

    {response_headers_map, _} = Code.eval_string(body)
    headers_decoded_from_body = Map.to_list(response_headers_map)

    assert {":status", "200"} in response_headers
    assert {"content-type", "application/json"} in headers_decoded_from_body
    assert {"accept", "application/json"} in headers_decoded_from_body
    assert {"apns-expiration", "apns expiration header value"} in headers_decoded_from_body
    assert {"apns-id", "apns id value"} in headers_decoded_from_body
    assert {"authorization", "bearer " <> @provider_token} in headers_decoded_from_body
    assert {"apns-priority", "apns priority value"} in headers_decoded_from_body
    assert {"apns-topic", "apns topic value"} in headers_decoded_from_body
    assert {"apns-collapse-id", "apns collapse id value"} in headers_decoded_from_body
  end
end
