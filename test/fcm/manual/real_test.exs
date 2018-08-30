defmodule Sparrow.FCM.Manual.RealTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.Notification
  alias Sparrow.H2Worker.Config

  @fcm_address "fcm.googleapis.com"
  # documentation says to use 5228, but 443 works fine
  @fcm_port 443
  @project_id "sparrow-2b961"
  @target_type :topic
  @target "news"

  @notification_title "Commander Cody"
  @notification_body "the time has come. Execute order 66."

  @android_title "Real life"
  @android_body "never heard of that server"

  @tag :skip
  test "real android notification send" do
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

    android_config =
      Sparrow.FCM.V1.AndroidConfig.new()
      |> Sparrow.FCM.V1.AndroidConfig.add_title(@android_title)
      |> Sparrow.FCM.V1.AndroidConfig.add_body(@android_body)

    notification =
      @notification_title
      |> Notification.new(
        @notification_body,
        @target_type,
        @target,
        @project_id
      )
      |> Notification.add_android_config(android_config)

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
