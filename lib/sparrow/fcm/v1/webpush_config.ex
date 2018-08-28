defmodule Sparrow.FCM.V1.WebpushConfig do
  @moduledoc """
  Struct reflecting FCM object(WebpushConfig).
  https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages?authuser=1#WebpushConfig
  """

  alias Sparrow.H2Worker.Request

  @type headers :: Request.headers()
  @type t :: %__MODULE__{
          headers: headers,
          data: map,
          web_notification: Sparrow.FCM.V1.WebNotification.t(),
          link: String.t()
        }

  defstruct [
    :headers,
    :data,
    :web_notification,
    :link
  ]

  @doc """
  Function to create new APNSConfig.

  ## Arguments

    * `link` - The link to open when the user clicks on the notification. For all URL values, HTTPS is required.
    * `data` - (optional) Arbitrary key/value payload. If present, it will override google.firebase.fcm.v1.Message.data.
  """
  @spec new(String.t(), map) :: t
  def new(link, data \\ %{}) do
    %__MODULE__{
      headers: [],
      data: data,
      web_notification: Sparrow.FCM.V1.WebNotification.new(),
      link: link
    }
  end

  @doc """
    Function to transfer WebpushConfig to map.
  """
  @spec to_map(t) :: map
  def to_map(webpush_config) do
    %{
      :headers => Map.new(webpush_config.headers),
      :data => webpush_config.data,
      :notification =>
        Sparrow.FCM.V1.WebNotification.to_map(webpush_config.web_notification),
      :fcm_options => %{
        :link => webpush_config.link
      }
    }
  end

  @doc """
  Function to add webpush header.
  HTTP headers defined in webpush protocol.
  Refer to Webpush protocol for supported headers, e.g. "TTL": "15".
  """
  @spec add_header(t, String.t(), String.t()) :: t
  def add_header(webpush_config, key, value) do
    %{webpush_config | headers: [{key, value} | webpush_config.headers]}
  end

  @doc """
  Function to set webpush permission
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_permission(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_permission(webpush_config, value) do
    add_to_web_notofication(webpush_config, :permission, value)
  end

  @doc """
  Function to set webpush actions
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_actions(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_actions(webpush_config, value) do
    add_to_web_notofication(webpush_config, :actions, value)
  end

  @doc """
  Function to set webpush badge
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_badge(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_badge(webpush_config, value) do
    add_to_web_notofication(webpush_config, :badge, value)
  end

  @doc """
  Function to set webpush body
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_body(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_body(webpush_config, value) do
    add_to_web_notofication(webpush_config, :body, value)
  end

  @doc """
  Function to set webpush web_notification_data
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_web_notification_data(t, Sparrow.FCM.V1.WebNotification.value()) ::
          t
  def add_web_notification_data(webpush_config, value) do
    add_to_web_notofication(webpush_config, :data, value)
  end

  @doc """
  Function to set webpush dir
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_dir(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_dir(webpush_config, value) do
    add_to_web_notofication(webpush_config, :dir, value)
  end

  @doc """
  Function to set webpush lang
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_lang(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_lang(webpush_config, value) do
    add_to_web_notofication(webpush_config, :lang, value)
  end

  @doc """
  Function to set webpush tag
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_tag(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_tag(webpush_config, value) do
    add_to_web_notofication(webpush_config, :tag, value)
  end

  @doc """
  Function to set webpush icon
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_icon(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_icon(webpush_config, value) do
    add_to_web_notofication(webpush_config, :icon, value)
  end

  @doc """
  Function to set webpush image
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_image(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_image(webpush_config, value) do
    add_to_web_notofication(webpush_config, :image, value)
  end

  @doc """
  Function to set webpush renotify
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_renotify(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_renotify(webpush_config, value) do
    add_to_web_notofication(webpush_config, :renotify, value)
  end

  @doc """
  Function to set webpush requireInteraction
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_requireInteraction(t, bool) :: t
  def add_requireInteraction(webpush_config, value) do
    add_to_web_notofication(webpush_config, :requireInteraction, value)
  end

  @doc """
  Function to set webpush silent
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_silent(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_silent(webpush_config, value) do
    add_to_web_notofication(webpush_config, :silent, value)
  end

  @doc """
  Function to set webpush timestamp
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_timestamp(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_timestamp(webpush_config, value) do
    add_to_web_notofication(webpush_config, :timestamp, value)
  end

  @doc """
  Function to set webpush title
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_title(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_title(webpush_config, value) do
    add_to_web_notofication(webpush_config, :title, value)
  end

  @doc """
  Function to set webpush vibrate
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_vibrate(t, Sparrow.FCM.V1.WebNotification.value()) :: t
  def add_vibrate(webpush_config, value) do
    add_to_web_notofication(webpush_config, :vibrate, value)
  end

  @spec add_to_web_notofication(
          t,
          Sparrow.FCM.V1.WebNotification.key(),
          Sparrow.FCM.V1.WebNotification.value()
        ) :: t
  defp add_to_web_notofication(webpush_config, key, value) do
    updated_web_notification =
      webpush_config.web_notification
      |> Sparrow.FCM.V1.WebNotification.add(key, value)

    %{webpush_config | web_notification: updated_web_notification}
  end
end
