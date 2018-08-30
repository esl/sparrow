defmodule Sparrow.FCM.Manual.RealWebpushTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Notification
  alias Sparrow.H2Worker.Config

  @fcm_address "fcm.googleapis.com"
  # documentation says to use 5228, but 443 works fine
  @fcm_port 443
  @project_id "sparrow-2b961"

  @webpush_title "Its Friday"
  @webpush_body "Oh no its actually Monday"

  #get token from browser
  @webpush_target_type :token
  @webpush_target "dummy"

  @tag :skip
  test "real webpush notification send" do
    auth =
      Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
        {:ok, token_map} =
          Goth.Token.for_scope(
            "https://www.googleapis.com/auth/firebase.messaging"
          )

        token = Map.get(token_map, :token)
        {"Authorization", "Bearer #{inspect(token)}"}
      end)

    config = Config.new(@fcm_address, @fcm_port, auth)
    worker_spec = child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)

    webpush_config =
      Sparrow.FCM.V1.WebpushConfig.new("www.google.com")
      |> Sparrow.FCM.V1.WebpushConfig.add_title(@webpush_title)
      |> Sparrow.FCM.V1.WebpushConfig.add_body(@webpush_body)


    notification =
      @notification_title
      |> Notification.new(
        @notification_body,
        @webpush_target_type,
        @webpush_target,
        @project_id
      )
      |> Notification.add_webpush_config(webpush_config)

    {:ok, {headers, body}} = Sparrow.FCMV1.push(worker_pid, notification)

    IO.puts("headers:")
    headers |> IO.inspect()
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
