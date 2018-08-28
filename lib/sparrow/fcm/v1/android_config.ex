defmodule Sparrow.FCM.V1.AndroidConfig do
  @moduledoc """
  Struct reflecting FCM object(AndroidConfig).
  Reflects https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#AndroidConfig
  """
  @type priority :: :NORMAL | :HIGH
  @type field ::
          {:collapse_key, String.t()}
          | {:priority | priority}
          | {:ttl, String.t()}
          | {:restricted_package_name, String.t()}
          | {:data, map}
  @type key ::
          :collapse_key
          | :priority
          | :ttl
          | :restricted_package_name
          | :data
  @type value :: String.t() | priority | map
  @type t :: %__MODULE__{
          fields: [field],
          notification: Sparrow.FCM.V1.AndroidNotification.t()
        }

  defstruct [
    :fields,
    :notification
  ]

  @doc """
  Create new empty AndroidConfig.
  """
  @spec new :: t
  def new do
    %__MODULE__{
      fields: [],
      notification: Sparrow.FCM.V1.AndroidNotification.new()
    }
  end

  @doc """
  Changes module to map for easier change to json.
  """
  @spec to_map(t) :: map
  def to_map(config) do
    notification =
      Sparrow.FCM.V1.AndroidNotification.to_map(config.notification)

    config.fields
    |> Map.new()
    |> Map.put(:notification, notification)
  end

  @doc """
  Adds collapse_key to AndroidConfig.
  """
  @spec add_collapse_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_collapse_key(config, value) do
    add(config, :collapse_key, value)
  end

  @doc """
  Adds priority to AndroidConfig.
  """
  @spec add_priority(__MODULE__.t(), priority) :: __MODULE__.t()
  def add_priority(config, :NORMAL) do
    add(config, :priority, :NORMAL)
  end

  def add_priority(config, :HIGH) do
    add(config, :priority, :HIGH)
  end

  @doc """
  Adds ttl to AndroidConfig.
  """
  @spec add_ttl(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_ttl(config, value) do
    add(config, :ttl, value)
  end

  @doc """
  Adds restricted_package_name to AndroidConfig.
  """
  @spec add_restricted_package_name(__MODULE__.t(), String.t()) ::
          __MODULE__.t()
  def add_restricted_package_name(config, value) do
    add(config, :restricted_package_name, value)
  end

  @doc """
  Adds data to AndroidConfig.
  """
  @spec add_data(__MODULE__.t(), map) :: __MODULE__.t()
  def add_data(config, value) do
    add(config, :data, value)
  end

  @doc """
  Adds title to the AndroidNotification.
  The notification's title.
  If present, it will override google.firebase.fcm.v1.Notification.title.
  """
  @spec add_title(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :title,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
  Adds body to the AndroidNotification.
  The notification's body text.
  If present, it will override google.firebase.fcm.v1.Notification.body.
  """
  @spec add_body(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :body,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
  Adds icon to the AndroidNotification.
  The notification's icon.
  Sets the notification icon to myicon for drawable resource myicon.
  If you don't send this key in the request,
  FCM displays the launcher icon specified in your app manifest.
  """
  @spec add_icon(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_icon(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :icon,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds color to the AndroidNotification.
    The notification's icon color, expressed in #rrggbb format.
  """
  @spec add_color(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_color(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :color,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds sound to the AndroidNotification.
    The sound to play when the device receives the notification.
    Supports "default" or the filename of a sound resource bundled in the app.
    Sound files must reside in /res/raw/.
  """
  @spec add_sound(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_sound(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :sound,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds tag to the AndroidNotification.
    Identifier used to replace existing notifications in the notification drawer.
    If not specified, each request creates a new notification.
    If specified and a notification with the same tag is already being shown,
    the new notification replaces the existing one in the notification drawer.
  """
  @spec add_tag(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_tag(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :tag,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds click_action to the AndroidNotification.
    The action associated with a user click on the notification.
    If specified, an activity with a matching intent filter is launched when a user clicks on the notification.
  """
  @spec add_click_action(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_click_action(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :click_action,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds body_loc_key to the AndroidNotification.
    The key to the body string in the app's string resources to use to localize the body text to the user's current localization.
    See String Resources (https://goo.gl/NdFZGI) for more information.
  """
  @spec add_body_loc_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body_loc_key(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :body_loc_key,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds body_loc_args[] to the AndroidNotification.
    Variable string values to be used in place of the format specifiers in body_loc_key to use to localize the body text to the user's current localization.
    See Formatting and Styling for more information.
  """
  @spec add_body_loc_args(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body_loc_args(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :"body_loc_args[]",
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds title_loc_key to the AndroidNotification.
    The key to the title string in the app's string resources to use to localize the title text to the user's current localization.
    See String Resources for more information.
  """
  @spec add_title_loc_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title_loc_key(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :title_loc_key,
        value
      )

    %{config | notification: updated_android_notification}
  end

  @doc """
    Adds title_loc_args[] to the AndroidNotification.
    Variable string values to be used in place of the format specifiers in title_loc_key to use to localize the title text to the user's current localization.
    See Formatting and Styling for more information.
  """
  @spec add_title_loc_args(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title_loc_args(config, value) do
    updated_android_notification =
      Sparrow.FCM.V1.AndroidNotification.add(
        config.notification,
        :"title_loc_args[]",
        value
      )

    %{config | notification: updated_android_notification}
  end

  @spec add(__MODULE__.t(), key, value) :: __MODULE__.t()
  defp add(config, key, value) do
    %{config | fields: [{key, value} | config.fields]}
  end
end
