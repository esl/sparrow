defmodule Sparrow.FCM.V1.TokenBearer do
  @moduledoc """
  Module providing FCM token.
  """

  require Logger

  @spec get_token(String.t()) :: String.t() | nil
  def get_token(account) do
    {:ok, token_map} =
      Goth.Token.for_scope({account, "https://www.googleapis.com/auth/firebase.messaging"})

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=get_token, result=success"
      end)

    Map.get(token_map, :token)
  end

  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(raw_fcm_config) do
    json =
      raw_fcm_config
      |> Enum.map(&decode_config/1)
      |> Jason.encode!()

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=start_link_read_json, result=success"
      end)

    Application.put_env(:goth, :json, json)

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=start_link_put_env, result=success"
      end)

    Goth.Supervisor.start_link()
  end

  defp decode_config(config) do
    config[:path_to_json]
    |> File.read!()
    |> Jason.decode!()
  end
end
