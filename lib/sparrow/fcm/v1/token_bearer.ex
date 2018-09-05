defmodule Sparrow.FCM.V1.TokenBearer do
  @moduledoc """
  Module providing FCM token.
  """

  use GenServer
  require Logger

  @spec get_token() :: String.t() | nil
  def get_token do
    {:ok, token_map} =
      Goth.Token.for_scope("https://www.googleapis.com/auth/firebase.messaging")

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=get_token, result=success"
      end)

    Map.get(token_map, :token)
  end

  @spec init(String.t()) :: {:ok, Path.t()}
  def init(google_json_path) do
    json = File.read!(google_json_path)

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=init_read_json, result=success"
      end)

    Application.put_env(:goth, :json, json)

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=init_put_env, result=success"
      end)

    Goth.Supervisor.start_link()

    _ =
      Logger.debug(fn ->
        "worker=fcm_token_bearer, action=init_starting_goth, result=success"
      end)

    {:ok, google_json_path}
  end

  @spec terminate(any, any) :: :ok
  def terminate(reason, _state) do
    _ =
      Logger.info(fn ->
        "worker=fcm_token_bearer, action=terminate, reason=#{inspect(reason)}"
      end)
  end

  @spec handle_info(any, Path.t()) :: {:noreply, Path.t()}
  def handle_info(unknown, state) do
    _ =
      Logger.warn(fn ->
        "worker=fcm_token_bearer, Unknown info #{inspect(unknown)}"
      end)

    {:noreply, state}
  end
end
