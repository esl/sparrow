defmodule Sparrow.FCM.V1.TokenBearer do
  @moduledoc """
  Module providing FCM token.
  """

  require Logger

  @spec get_token(String.t()) :: String.t() | nil
  def get_token(account) do
    {:ok, token_map} = Goth.fetch(account)

    _ =
      Logger.debug("Fetching FCM token",
        worker: :fcm_token_bearer,
        what: :get_token,
        result: :success
      )

    Map.get(token_map, :token)
  end

  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(raw_fcm_config) do
    scopes = ["https://www.googleapis.com/auth/firebase.messaging"]

    opts = [
      {:scopes, scopes}
      | maybe_url()
    ]

    children =
      raw_fcm_config
      |> Enum.map(&decode_config/1)
      |> Enum.map(fn %{"client_email" => account} = json ->
        Supervisor.child_spec(
          {Goth, name: account, source: {:service_account, json, opts}},
          id: account
        )
      end)

    _ =
      Logger.debug("Starting FCM TokenBearer",
        worker: :fcm_token_bearer,
        what: :start_link,
        result: :success
      )

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp decode_config(config) do
    config[:path_to_json]
    |> File.read!()
    |> Jason.decode!()
  end

  defp maybe_url do
    case Application.get_env(:sparrow, :google_auth_url) do
      nil -> []
      url -> [{:url, url}]
    end
  end
end
