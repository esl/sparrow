defmodule Sparrow.FCM.V1.Android do
  @moduledoc """
  Struct reflecting FCM object(AndroidConfig).
  See: https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#AndroidConfig
  """
  @type priority :: :NORMAL | :HIGH
  @type field ::
          {:collapse_key, String.t()}
          | {:priority, priority}
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
          notification: Sparrow.FCM.V1.Android.Notification.t()
        }

  defstruct [
    :fields,
    :notification
  ]

  @doc """
  Create new empty `Sparrow.FCM.V1.Android`.
  """
  @spec new :: t
  def new do
    %__MODULE__{
      fields: [],
      notification: Sparrow.FCM.V1.Android.Notification.new()
    }
  end

  @doc """
  Changes `Sparrow.FCM.V1.Android` to map for easier change to json.
  """
  @spec to_map(t) :: map
  def to_map(android) do
    notification = Sparrow.FCM.V1.Android.Notification.to_map(android.notification)

    android.fields
    |> Map.new()
    |> Map.put(:notification, notification)
  end

  @doc """
  Adds collapse_key to `Sparrow.FCM.V1.Android`.
  """
  @spec add_collapse_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_collapse_key(android, value) do
    add(android, :collapse_key, value)
  end

  @doc """
  Adds priority to `Sparrow.FCM.V1.Android`.
  """
  @spec add_priority(__MODULE__.t(), priority) :: __MODULE__.t()
  def add_priority(android, :NORMAL) do
    add(android, :priority, :NORMAL)
  end

  def add_priority(android, :HIGH) do
    add(android, :priority, :HIGH)
  end

  @doc """
  Adds ttl to `Sparrow.FCM.V1.Android`.

  ## Arguments
   * `android` -  Sparrow.FCM.V1.Android struct you want add `ttl` param to.
   * 'value' - non_neg_integer value (in seconds) that will be converted to correct format: 5 -> "5s"
  """
  @spec add_ttl(__MODULE__.t(), non_neg_integer) :: __MODULE__.t()
  def add_ttl(android, value) do
    string_value = Integer.to_string(value) <> "s"
    add(android, :ttl, string_value)
  end

  @doc """
  Adds restricted_package_name to `Sparrow.FCM.V1.Android`.
  """
  @spec add_restricted_package_name(__MODULE__.t(), String.t()) ::
          __MODULE__.t()
  def add_restricted_package_name(android, value) do
    add(android, :restricted_package_name, value)
  end

  @doc """
  Adds data to `Sparrow.FCM.V1.Android`.
  """
  @spec add_data(__MODULE__.t(), map) :: __MODULE__.t()
  def add_data(android, value) do
    add(android, :data, value)
  end

  @doc """
  Adds title to the `Sparrow.FCM.V1.Android`.
  The notification's title.
  If present, it will override google.firebase.fcm.v1.Notification.title.
  """
  @spec add_title(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :title,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
  Adds body to the `Sparrow.FCM.V1.Android`.
  The notification's body text.
  If present, it will override google.firebase.fcm.v1.Notification.body.
  """
  @spec add_body(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :body,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
  Adds icon to the `Sparrow.FCM.V1.Android`.
  The notification's icon.
  Sets the notification icon to myicon for drawable resource myicon.
  If you don't send this key in the request,
  FCM displays the launcher icon specified in your app manifest.
  """
  @spec add_icon(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_icon(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :icon,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds color to the `Sparrow.FCM.V1.Android`.
    The notification's icon color, expressed in #rrggbb format.
  """
  @spec add_color(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_color(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :color,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds sound to the `Sparrow.FCM.V1.Android`.
    The sound to play when the device receives the notification.
    Supports "default" or the filename of a sound resource bundled in the app.
    Sound files must reside in /res/raw/.
  """
  @spec add_sound(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_sound(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :sound,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds tag to the `Sparrow.FCM.V1.Android`.
    Identifier used to replace existing notifications in the notification drawer.
    If not specified, each request creates a new notification.
    If specified and a notification with the same tag is already being shown,
    the new notification replaces the existing one in the notification drawer.
  """
  @spec add_tag(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_tag(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :tag,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds click_action to the `Sparrow.FCM.V1.Android`.
    The action associated with a user click on the notification.
    If specified, an activity with a matching intent filter is launched when a user clicks on the notification.
  """
  @spec add_click_action(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_click_action(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :click_action,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds body_loc_key to the `Sparrow.FCM.V1.Android`.
    The key to the body string in the app's string resources to use to localize the body text to the user's current localization.
    See String Resources (https://goo.gl/NdFZGI) for more information.
  """
  @spec add_body_loc_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body_loc_key(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :body_loc_key,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds body_loc_args[] to the `Sparrow.FCM.V1.Android`.
    Variable string values to be used in place of the format specifiers in body_loc_key to use to localize the body text to the user's current localization.
    See Formatting and Styling for more information.
  """
  @spec add_body_loc_args(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_body_loc_args(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :"body_loc_args[]",
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds title_loc_key to the `Sparrow.FCM.V1.Android`.
    The key to the title string in the app's string resources to use to localize the title text to the user's current localization.
    See String Resources for more information.
  """
  @spec add_title_loc_key(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title_loc_key(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :title_loc_key,
        value
      )

    %{android | notification: updated_android_notification}
  end

  @doc """
    Adds title_loc_args[] to the `Sparrow.FCM.V1.Android`.
    Variable string values to be used in place of the format specifiers in title_loc_key to use to localize the title text to the user's current localization.
    See Formatting and Styling for more information.
  """
  @spec add_title_loc_args(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def add_title_loc_args(android, value) do
    updated_android_notification =
      Sparrow.FCM.V1.Android.Notification.add(
        android.notification,
        :"title_loc_args[]",
        value
      )

    %{android | notification: updated_android_notification}
  end

  @spec add(__MODULE__.t(), key, value) :: __MODULE__.t()
  defp add(android, key, value) do
    %{android | fields: [{key, value} | android.fields]}
  end

  @spec normalize(t | nil) ::
          {:ok, t | nil} | {:error, :invalid_notification}
  def normalize(nil), do: {:ok, nil}

  def normalize(notification) do
    case Keyword.get(notification.fields, :data) do
      nil ->
        {:ok, notification}

      data ->
        data = Enum.map(data, &normalize_value/1)

        case Enum.all?(data) do
          false ->
            {:error, :invalid_notification}

          true ->
            {:ok,
             %{
               notification
               | fields: Keyword.put(notification.fields, :data, Map.new(data))
             }}
        end
    end
  end

  defp normalize_value({k, v}) do
    {k, to_string(v)}
  rescue
    Protocol.UndefinedError -> false
  end
end
