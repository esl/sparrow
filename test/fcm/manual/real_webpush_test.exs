defmodule Sparrow.FCM.Manual.RealWebpushTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Notification
  alias Sparrow.H2Worker.Config

  @fcm_address "fcm.googleapis.com"
  # documentation says to use 5228, but 443 works fine
  @fcm_port 443
  @project_id "sparrow-2b961"
  @webpush_title "TORA"
  @webpush_body "TORA TORA"
  # get token from browser
  @webpush_target_type :token
  @webpush_target "dummy"
  @pool_name :my_pool_name
  @path_to_json "priv/fcm/token/sparrow_token.json"
  @tag :skip
  test "real webpush notification send" do
    Sparrow.FCM.V1.TokenBearer.start_link(@path_to_json)

    {:ok, _pid} = Sparrow.PoolsWarden.start_link()

    worker_config =
      Sparrow.FCM.V1.get_token_based_authentication()
      |> Sparrow.FCM.V1.get_h2worker_config()

    {:ok, pid} =
      Sparrow.H2Worker.Pool.Config.new(worker_config, @pool_name)
      |> Sparrow.H2Worker.Pool.start_link(:fcm, [:webpush])

    webpush =
      Sparrow.FCM.V1.Webpush.new("www.google.com")
      |> Sparrow.FCM.V1.Webpush.add_title(@webpush_title)
      |> Sparrow.FCM.V1.Webpush.add_body(@webpush_body)

    notification =
      @webpush_target_type
      |> Notification.new(
        @webpush_target,
        @project_id
      )
      |> Notification.add_webpush(webpush)

      #{:ok, {headers, body}} = Sparrow.FCM.V1.push(@pool_name, notification)

      {:ok, {headers, body}} = Sparrow.API.push(notification, [:webpush])

      IO.puts("headers:")
      IO.inspect(headers)
      IO.puts("body:")
      body |> Jason.decode!() |> IO.inspect()
  end

  def child_spec(opts) do
    args = opts[:args]
    name = opts[:name]

    %{
      :id => 28,
      :start => {Sparrow.H2Worker, :start_link, [name, args]}
    }
  end
end
