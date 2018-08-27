defmodule Sparrow.FCMV1 do
  @moduledoc """
  Provides functions to build and send push notifications to FCM v1
  """
  require Logger

  alias Sparrow.H2Worker.Request

  @type reason :: any
  @type headers :: Request.headers()
  @type body :: String.t()
  @type push_opts :: [{:is_sync, boolean()} | {:timeout, non_neg_integer}]
  @type android_config :: Sparrow.FCM.V1.Notification.android_config()
  @type webpush_config :: Sparrow.FCM.V1.Notification.webpush_config()
  @type apns_config :: Sparrow.FCM.V1.Notification.apns_config()
  @spec push(
          Sparrow.H2Worker.process(),
          Sparrow.FCM.V1.Notification.t(),
          push_opts
        ) ::
          {:error, :connection_lost}
          | {:ok, {headers, body}}
          | {:error, :request_timeout}
          | {:error, :not_ready}
          | {:error, :invalid_notification}
          | {:error, reason}
          | :ok
  def push(h2_worker, notification, opts \\ []) do
    is_sync = Keyword.get(opts, :is_sync, true)
    timeout = Keyword.get(opts, :timeout, 5_000)
    headers = notification.headers
    json_body = notification |> make_body() |> Jason.encode!()
    path = path(notification.project_id)
    request = Request.new(headers, json_body, path, timeout)

    _ =
      Logger.debug(fn ->
        "action=push_fcm_notification, request=#{inspect(request)}"
      end)

    Sparrow.H2Worker.send_request(h2_worker, request, is_sync, timeout)
  end

  @spec make_body(Sparrow.FCM.V1.Notification.t()) :: map
  defp make_body(notification) do
    %{
      :data => notification.data,
      :notification => %{
        :title => notification.title,
        :body => notification.body
      },
      notification.target_type => notification.target
    }
    |> maybe_add_android_config(notification.android_config)
    |> maybe_add_webpush_config(notification.webpush_config)
    |> maybe_add_apns_config(notification.apns_config)
  end

  @spec maybe_add_android_config(map, android_config) :: map
  defp maybe_add_android_config(body, nil) do
    body
  end

  defp maybe_add_android_config(body, android_config) do
    Map.put(body, :android, Sparrow.FCM.V1.AndroidConfig.to_map(android_config))
  end

  @spec maybe_add_webpush_config(map, webpush_config) :: map
  defp maybe_add_webpush_config(body, nil) do
    body
  end

  defp maybe_add_webpush_config(body, webpush_config) do
    Map.put(body, :webpush, Sparrow.FCM.V1.WebpushConfig.to_map(webpush_config))
  end

  @spec maybe_add_apns_config(map, apns_config) :: map
  defp maybe_add_apns_config(body, nil) do
    body
  end

  defp maybe_add_apns_config(body, apns_config) do
    # Map.put(body, :apns, to_map(apns_config))
    # TODO add implementation
    body
  end

  @spec path(String.t()) :: String.t()
  defp path(project_id) do
    "/v1/projects/#{project_id}/messages:send"
  end
end
