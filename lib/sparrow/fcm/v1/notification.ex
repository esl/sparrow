defmodule Sparrow.FCM.V1.Notification do
  @moduledoc """
  Struct representing single FCM.V1 notification.

  For details on the FCM.V1 notification payload structure see the following links:
    * https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages
  """

  alias Sparrow.H2Worker.Request

  @type target_type :: :token | :topic | :condition
  @type android :: nil | Sparrow.FCM.V1.Android.t()
  @type webpush :: nil | Sparrow.FCM.V1.Webpush.t()
  @type apns :: nil | Sparrow.FCM.V1.APNS.t()
  @type headers :: Request.headers()
  @type t :: %__MODULE__{
          project_id: String.t() | nil,
          headers: headers,
          data: map,
          title: String.t() | nil,
          body: String.t() | nil,
          android: android,
          webpush: webpush,
          apns: apns,
          target: {target_type, String.t()}
        }

  @headers [{"content-type", "application/json"}]

  defstruct [
    :project_id,
    :headers,
    :data,
    :title,
    :body,
    :android,
    :webpush,
    :apns,
    :target,
    :target_type
  ]

  @doc """
  Creates new notification.

  ## Arguments

    * `target` - Target to send a message to.
    * `target_type` can be only one of the following:
      * `:token` - Registration token to send a message to.
      * `:topic` - Topic name to send a message to, e.g. "weather". Note: "/topics/" prefix should not be provided.
      * `:condition` - Condition to send a message to, e.g. "'foo' in topics && 'bar' in topics".
    * `title` - The notification's title.
    * `body` - The notification's body text.
    * `data` - An object containing a list of `"key"`: value pairs. Example: `{ "name": "wrench", "mass": "1.3kg", "count": "3" }`.
  """
  @spec new(
          target_type,
          String.t(),
          String.t() | nil,
          String.t() | nil,
          map
        ) :: t
  def new(
        target_type,
        target,
        title \\ nil,
        body \\ nil,
        data \\ %{}
      ) do
    %__MODULE__{
      project_id: nil,
      headers: @headers,
      data: data,
      title: title,
      body: body,
      android: nil,
      webpush: nil,
      apns: nil,
      target: target,
      target_type: target_type
    }
  end

  @doc """
  Add `Sparrow.FCM.V1.Android` to `Sparrow.FCM.V1.Notification`.
  """
  @spec add_android(t, android) :: t
  def add_android(notification, config) do
    %{notification | android: config}
  end

  @doc """
  Add `Sparrow.FCM.V1.Webpush` to `Sparrow.FCM.V1.Notification`.
  """
  @spec add_webpush(t, webpush) :: t
  def add_webpush(notification, config) do
    %{notification | webpush: config}
  end

  @doc """
  Add `Sparrow.FCM.V1.APNS` to `Sparrow.FCM.V1.Notification`.
  """
  @spec add_apns(t, apns) :: t
  def add_apns(notification, config) do
    %{notification | apns: config}
  end

  @doc """
  Add `project_id` to `Sparrow.FCM.V1.Notification`.
  WARNING This function is called automatically when pushing notification.
  There is NO need to cally it manually when creating notiifcation.
  """
  @spec add_project_id(t, project_id :: String.t()) :: t
  def add_project_id(notification, project_id) do
    %{notification | project_id: project_id}
  end
end
