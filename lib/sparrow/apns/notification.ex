defmodule Sparrow.APNS.Notification do
  @moduledoc """
  Struct representing single APNS notification.

  For details on the APNS notification payload structure see the following links:
    * https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW1
    * https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html#//apple_ref/doc/uid/TP40008194-CH17-SW1

  This module contains a bunch of helper functions which allow you to build the notification conveniently.

    ## Example

    notification = Sparrow.APNS.Notification.new(device_token)
    |> add_title("some example title")
    |> add_body("some example body")
    |> add_apns_id("some apns id")
    |> add_apns_topic("apns topic of some kind")
    ...
  """
  alias Sparrow.H2Worker.Request

  @type alert_opt_key ::
          :"title-loc-key"
          | :"title-loc-args"
          | :"action-loc-key"
          | :"loc-key"
          | :"loc-args"
          | :"launch-image"
          | :title
          | :body
  @type alert_opts :: [{alert_opt_key, String.t()}]
  @type aps_dictionary_opts :: [aps_dictionary_opt]
  @type aps_dictionary_key :: :badge | :sound | :"content-available" | :category | :"thread-id"
  @type aps_dictionary_opt ::
          {:badge, integer}
          | {:sound, String.t()}
          | {:"content-available", integer}
          | {:category, String.t()}
          | {:"thread-id", String.t()}
  @type headers :: Request.headers()
  @type t :: %__MODULE__{
          device_token: String.t(),
          headers: headers,
          alert_opts: alert_opts,
          aps_dictionary_opts: aps_dictionary_opts
        }
  defstruct [
    :device_token,
    :headers,
    :alert_opts,
    :aps_dictionary_opts
  ]

  @doc """
  Creates new notification.
  """
  @spec new(String.t()) :: __MODULE__.t()
  def new(device_token) do
    %__MODULE__{
      device_token: device_token,
      headers: [{"content-type", "application/json"}, {"accept", "application/json"}],
      alert_opts: [],
      aps_dictionary_opts: []
    }
  end

  @doc """
  Sets the `badge` option of the aps dictionary.
  """
  @spec add_badge(__MODULE__.t(), integer) :: __MODULE__.t()
  def add_badge(notification, value) do
    add_aps_dictionary_opt(notification, :badge, value)
  end

  @doc """
  Sets the `sound` option of the aps dictionary.
  """
  @spec add_sound(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_sound(notification, value) do
    add_aps_dictionary_opt(notification, :sound, value)
  end

  @doc """
  Sets the `content-available` option of the aps dictionary.
  """
  @spec add_content_available(__MODULE__.t(), integer) :: __MODULE__.t()
  def add_content_available(notification, value) do
    add_aps_dictionary_opt(notification, :"content-available", value)
  end

  @doc """
  Sets the `category` option of the aps dictionary.
  """
  @spec add_category(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_category(notification, value) do
    add_aps_dictionary_opt(notification, :category, value)
  end

  @doc """
  Sets the `thread-id` option of the aps dictionary.
  """
  @spec add_thread_id(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_thread_id(notification, value) do
    add_aps_dictionary_opt(notification, :"thread-id", value)
  end

  @doc """
  Sets the `title` option of the alert dictionary.
  """
  @spec add_title(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title(notification, title) do
    add_alert_opt(notification, :title, title)
  end

  @doc """
  Sets the `body` option of the alert dictionary.
  """
  @spec add_body(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body(notification, body) do
    add_alert_opt(notification, :body, body)
  end

  @doc """
  Sets the `title-loc-key` option of the alert dictionary.
  """
  @spec add_title_loc_key(__MODULE__.t(), String.t() | nil) :: __MODULE__.t()
  def add_title_loc_key(notification, value) do
    add_alert_opt(notification, :"title-loc-key", value)
  end

  @doc """
  Sets the `title-loc-args` option of the alert dictionary.
  """
  @spec add_title_loc_args(__MODULE__.t(), [String.t()] | nil) :: __MODULE__.t()
  def add_title_loc_args(notification, value) do
    add_alert_opt(notification, :"title-loc-args", value)
  end

  @doc """
  Sets the `action-loc-key` option of the alert dictionary.
  """
  @spec add_action_loc_key(__MODULE__.t(), String.t() | nil) :: __MODULE__.t()
  def add_action_loc_key(notification, value) do
    add_alert_opt(notification, :"action-loc-key", value)
  end

  @doc """
  Sets the `loc-key` option of the alert dictionary.
  """
  @spec add_loc_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_loc_key(notification, value) do
    add_alert_opt(notification, :"loc-key", value)
  end

  @doc """
  Sets the `loc-args` option of the alert dictionary.
  """
  @spec add_loc_args(__MODULE__.t(), [String.t()]) :: __MODULE__.t()
  def add_loc_args(notification, value) do
    add_alert_opt(notification, :"loc-args", value)
  end

  @doc """
  Sets the `launch-image` option of the alert dictionary.
  """
  @spec add_launch_image(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_launch_image(notification, value) do
    add_alert_opt(notification, :"launch-image", value)
  end

  @doc """
  Sets the `apns-id` header.
  """
  @spec add_apns_id(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_apns_id(notification, value), do: add_header(notification, "apns-id", value)

  @doc """
  Sets the `apns-expiration` header.
  """
  @spec add_apns_expiration(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_apns_expiration(notification, value),
    do: add_header(notification, "apns-expiration", value)

  @doc """
  Sets the `apns-priority` header.
  """
  @spec add_apns_priority(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_apns_priority(notification, value),
    do: add_header(notification, "apns-priority", value)

  @doc """
  Sets the `apns-topic` header.
  """
  @spec add_apns_topic(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_apns_topic(notification, value),
    do: add_header(notification, "apns-topic", value)

  @doc """
  Sets the `apns-collapse-id` header.
  """
  @spec add_apns_collapse_id(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_apns_collapse_id(notification, value),
    do: add_header(notification, "apns-collapse-id", value)

  @spec add_header(__MODULE__.t(), String.t(), String.t()) :: __MODULE__.t()
  defp add_header(notification, key, value),
    do: %{notification | headers: [{key, value} | notification.headers]}

  @spec add_alert_opt(__MODULE__.t(), alert_opt_key, String.t() | [String.t()] | nil) ::
          __MODULE__.t()
  defp add_alert_opt(notification, key, value),
    do: %{notification | alert_opts: [{key, value} | notification.alert_opts]}

  @spec add_aps_dictionary_opt(__MODULE__.t(), aps_dictionary_key, String.t() | integer) ::
          __MODULE__.t()
  defp add_aps_dictionary_opt(notification, key, value),
    do: %{notification | aps_dictionary_opts: [{key, value} | notification.aps_dictionary_opts]}
end
