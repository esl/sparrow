defmodule Sparrow.APNS.Manual.RealIosTest do
  use ExUnit.Case

  alias Sparrow.H2Worker.Config
  alias Sparrow.APNS.Notification

  @apns_address_a "api.development.push.apple.com"
  @apns_port 2197
  @device_token System.get_env("TOKENDEVICE")
  @apns_topic System.get_env("APNSTOPIC")
  @key_id System.get_env("KEYID")
  @team_id System.get_env("TEAMID")
  @p8_file_path "token.p8"

  @path_to_cert "test/priv/certs/Certificates1.pem"
  @path_to_key "test/priv/certs/key.pem"

  @title "Commander Cody"
  @body "the time has come. Execute order 66."

  @tag :skip
  test "real notification certificate based authentication test" do
    auth = Sparrow.H2Worker.Authentication.CertificateBased.new(@path_to_cert, @path_to_key)
    config = Config.new(@apns_address_a, @apns_port, auth)
    worker_spec = child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)

    notification =
      Notification.new(@device_token)
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_topic(@apns_topic)

    IO.inspect(Sparrow.APNS.push(worker_pid, notification))
  end

  @tag :skip
  test "real notification token based authentication test" do
    opts = Sparrow.APNS.Token.new(@key_id, @team_id, @p8_file_path, 2000)

    {:ok, pid} = Sparrow.APNS.TokenBearer.init(opts)
    {:ok, token_bearer: pid}

    auth =
      Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
        {"authorization", "bearer #{Sparrow.APNS.TokenBearer.get_token()}"}
      end)

    config = Config.new(@apns_address_a, @apns_port, auth)
    worker_spec = child_spec(args: config, name: :name)
    {:ok, worker_pid} = start_supervised(worker_spec)
    token = Sparrow.APNS.TokenBearer.get_token()

    notification =
      Notification.new(@device_token)
      |> Notification.add_title(@title)
      |> Notification.add_body(@body)
      |> Notification.add_apns_topic(@apns_topic)

    IO.inspect(Sparrow.APNS.push(worker_pid, notification))
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
