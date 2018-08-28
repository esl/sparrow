defmodule Sparrow.FCM.V1.Notification do
  @moduledoc """
  Struct representing single FCM.V1 notification.

  For details on the FCM.V1 notification payload structure see the following links:
    * https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages
  """

  alias Sparrow.H2Worker.Request

  @type target_type :: :token | :topic | :condition
  @type android_config :: nil | Sparrow.FCM.V1.AndroidConfig.t()
  @type webpush_config :: nil | Sparrow.FCM.V1.WebpushConfig.t()
  @type apns_config :: nil | Sparrow.FCM.V1.APNSConfig.t()
  @type headers :: Request.headers()
  @type t :: %__MODULE__{
          project_id: String.t(),
          headers: headers,
          data: map,
          title: String.t(),
          body: String.t(),
          android_config: android_config,
          webpush_config: webpush_config,
          apns_config: apns_config,
          target: {target_type, String.t()}
        }

  @headers [{"content-type", "application/json"}]

  defstruct [
    :project_id,
    :headers,
    :data,
    :title,
    :body,
    :android_config,
    :webpush_config,
    :apns_config,
    :target,
    :target_type
  ]

  @doc """
  Creates new notification.

  ## Arguments

    * `title` - The notification's title.
    * `body` - The notification's body text.
    * `target` - Target to send a message to.
    * `target_type` can be only one of the following:
      * `:token` - Registration token to send a message to.
      * `:topic` - Topic name to send a message to, e.g. "weather". Note: "/topics/" prefix should not be provided.
      * `:condition` - Condition to send a message to, e.g. "'foo' in topics && 'bar' in topics".
    * `configs` - List of [android | webpush | apns ] configs. For details see `Sparrow.FCM.V1.AndroidConfig`, `Sparrow.FCM.V1.WebpushConfig`, `Sparrow.FCM.V1.APNSConfig`
    * `data` - An object containing a list of `"key"`: value pairs. Example: `{ "name": "wrench", "mass": "1.3kg", "count": "3" }`.
  """
  @spec new(
          String.t(),
          String.t(),
          target_type,
          String.t(),
          String.t(),
          map
        ) :: t
  def new(title, body, target_type, target, project_id, data \\ %{}) do
    %__MODULE__{
      project_id: project_id,
      headers: @headers,
      data: data,
      title: title,
      body: body,
      android_config: nil,
      webpush_config: nil,
      apns_config: nil,
      target: target,
      target_type: target_type
    }
  end

  @doc """
  Add AndroidConfig to Notification.
  """
  @spec add_android_config(t, android_config) :: t
  def add_android_config(notification, config) do
    %{notification | android_config: config}
  end

  @doc """
  Add WebpushConfig to Notification.
  """
  @spec add_webpush_config(t, webpush_config) :: t
  def add_webpush_config(notification, config) do
    %{notification | webpush_config: config}
  end

  @doc """
  Add APNSConfig to Notification.
  """
  @spec add_apns_config(t, apns_config) :: t
  def add_apns_config(notification, config) do
    %{notification | apns_config: config}
  end
end
