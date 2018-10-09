defmodule Sparrow do
  @moduledoc """
  Sparrow is service providing ability to send push
  notification to `FCM` (Firebase Cloud Messaging) and/or
  `APNS` (Apple Push Notification Service).
  """
  use Application

  def start(_type, _args) do
    raw_config = Application.get_env(:sparrow, :config)
    start(raw_config)
  end

  @spec start(Keyword.t()) :: Supervisor.on_start()
  def start(raw_config) do
    raw_fcm_config = Keyword.get(raw_config, :fcm)
    raw_apns_config = Keyword.get(raw_config, :apns)

    children =
      if raw_apns_config == nil and raw_fcm_config == nil do
        []
      else
        [
          Sparrow.PoolsWarden
        ]
        |> maybe_append({Sparrow.FCM.V1.Supervisor, raw_fcm_config})
        |> maybe_append({Sparrow.APNS.Supervisor, raw_apns_config})
      end

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  @spec maybe_append([any], {any, nil | list}) :: [any]
  defp maybe_append(list, {_, nil}), do: list
  defp maybe_append(list, elem), do: list ++ [elem]
end
