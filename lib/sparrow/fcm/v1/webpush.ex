defmodule Sparrow.FCM.V1.Webpush do
  @moduledoc """
  Struct reflecting FCM object(WebpushConfig).
  https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages?authuser=1#WebpushConfig
  """

  alias Sparrow.H2Worker.Request

  @type headers :: Request.headers()
  @type t :: %__MODULE__{
          headers: headers,
          data: map,
          web_notification: Sparrow.FCM.V1.Webpush.Notification.t(),
          link: String.t()
        }

  defstruct [
    :headers,
    :data,
    :web_notification,
    :link
  ]

  @doc """
  Function to create new `Sparrow.FCM.V1.Webpush`.

  ## Arguments

    * `link` - The link to open when the user clicks on the notification. For all URL values, HTTPS is required.
    * `data` - (optional) Arbitrary key/value payload. If present, it will override google.firebase.fcm.v1.Message.data.
  """
  @spec new(String.t(), map) :: t
  def new(link, data \\ %{}) do
    %__MODULE__{
      headers: [],
      data: data,
      web_notification: Sparrow.FCM.V1.Webpush.Notification.new(),
      link: link
    }
  end

  @doc """
    Function to transfer`Sparrow.FCM.V1.Webpush` to map.
  """
  @spec to_map(t) :: map
  def to_map(webpush) do
    %{
      :headers => Map.new(webpush.headers),
      :data => webpush.data,
      :notification =>
        Sparrow.FCM.V1.Webpush.Notification.to_map(webpush.web_notification),
      :fcm_options => %{
        :link => webpush.link
      }
    }
  end

  @doc """
  Function to add `Sparrow.FCM.V1.Webpush` header.
  HTTP headers defined in Webpush protocol.
  Refer to Webpush protocol for supported headers, e.g. "TTL": "15".
  """
  @spec add_header(t, String.t(), String.t()) :: t
  def add_header(webpush, key, value) do
    %{webpush | headers: [{key, value} | webpush.headers]}
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` permission
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_permission(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_permission(webpush, value) do
    add_to_web_notofication(webpush, :permission, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` actions
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_actions(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_actions(webpush, value) do
    add_to_web_notofication(webpush, :actions, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` badge
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_badge(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_badge(webpush, value) do
    add_to_web_notofication(webpush, :badge, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` body
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_body(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_body(webpush, value) do
    add_to_web_notofication(webpush, :body, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` web_notification_data
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_web_notification_data(
          t,
          Sparrow.FCM.V1.Webpush.Notification.value()
        ) :: t
  def add_web_notification_data(webpush, value) do
    add_to_web_notofication(webpush, :data, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` dir
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_dir(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_dir(webpush, value) do
    add_to_web_notofication(webpush, :dir, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` lang
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_lang(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_lang(webpush, value) do
    add_to_web_notofication(webpush, :lang, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` tag
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_tag(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_tag(webpush, value) do
    add_to_web_notofication(webpush, :tag, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` icon
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_icon(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_icon(webpush, value) do
    add_to_web_notofication(webpush, :icon, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` image
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_image(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_image(webpush, value) do
    add_to_web_notofication(webpush, :image, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` renotify
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_renotify(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_renotify(webpush, value) do
    add_to_web_notofication(webpush, :renotify, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` requireInteraction
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_requireInteraction(t, boolean) :: t
  def add_requireInteraction(webpush, value) do
    add_to_web_notofication(webpush, :requireInteraction, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` silent
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_silent(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_silent(webpush, value) do
    add_to_web_notofication(webpush, :silent, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` timestamp
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_timestamp(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_timestamp(webpush, value) do
    add_to_web_notofication(webpush, :timestamp, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` title
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_title(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_title(webpush, value) do
    add_to_web_notofication(webpush, :title, value)
  end

  @doc """
  Function to set `Sparrow.FCM.V1.Webpush` vibrate
  See https://developer.mozilla.org/en-US/docs/Web/API/Notification
  """
  @spec add_vibrate(t, Sparrow.FCM.V1.Webpush.Notification.value()) :: t
  def add_vibrate(webpush, value) do
    add_to_web_notofication(webpush, :vibrate, value)
  end

  @spec add_to_web_notofication(
          t,
          Sparrow.FCM.V1.Webpush.Notification.key(),
          Sparrow.FCM.V1.Webpush.Notification.value()
        ) :: t
  defp add_to_web_notofication(webpush, key, value) do
    updated_web_notification =
      webpush.web_notification
      |> Sparrow.FCM.V1.Webpush.Notification.add(key, value)

    %{webpush | web_notification: updated_web_notification}
  end

  @spec verify(t | nil) :: t | nil | {:error, :invalid_notification}

  def verify(nil), do: nil

  def verify(notification) do
    data = Enum.map(notification.data, &verify_value/1)

    case Enum.all?(data) do
      false ->
        {:error, :invalid_notification}

      true ->
        %{notification | data: Map.new(data)}
    end
  end

  defp verify_value({k, v}) do
    {k, to_string(v)}
  rescue
    _ -> false
  end
end
