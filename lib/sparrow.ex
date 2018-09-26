defmodule Sparrow do
  @moduledoc """
  Sparrow is service providing ability to send push
  notification to `FCM` (Firebase Cloud Messaging) and/or
  `APNS` (Apple Push Notification Service).
  """
  use Application

  def start(_type, _args) do
    raw_fcm_config = Application.get_env(:sparrow, :fcm)
    raw_apns_config = Application.get_env(:sparrow, :apns)

    children =
      if raw_apns_config == nil and raw_fcm_config == nil do
        []
      else
        [
          %{
            id: Sparrow.PoolsWarden,
            start: {Sparrow.PoolsWarden, :start_link, []}
          }
        ]
        |> maybe_append({Sparrow.FCMSupervisor, raw_fcm_config})
        |> maybe_append({Sparrow.APNSSupervisor, raw_apns_config})
      end

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp maybe_append(list, {_, nil}), do: list
  defp maybe_append(list, elem), do: [elem | list]
end
