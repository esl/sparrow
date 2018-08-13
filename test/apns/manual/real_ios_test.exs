defmodule Sparrow.APNS.Manual.RealIosTest do
  use ExUnit.Case

  alias Sparrow.H2Worker.Config
  alias Sparrow.APNS.Notification

  @apns_address_a "api.development.push.apple.com"
  @apns_port 2197
  @device_token System.get_env("TOKENDEVICE")
  @apns_topic System.get_env("APNSTOPIC")

  @title "Commander Cody"
  @body "the time has come. Execute order 66"

  @tag :skip
  test "real notification test" do
    config = Config.new(@apns_address_a, @apns_port, tls_opts())
    worker_spec = child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)

    notification =
      Notification.new(@device_token)
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_topic(@apns_topic)

    IO.inspect(Sparrow.APNS.push(worker_pid, notification))
  end

  defp tls_opts() do
    [
      {:certfile, "test/priv/certs/Certificates1.pem"},
      {:keyfile, "test/priv/certs/key.pem"}
    ]
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
