defmodule Sparrow.FCM.V1.WebNotification do
  @moduledoc false
  @type permission :: :denied | :granted | :default
  @type field ::
          {:permission, permission}
          | {:actions, String.t()}
          | {:badge, String.t()}
          | {:body, String.t()}
          | {:data, map}
          | {:dir, String.t()}
          | {:lang, String.t()}
          | {:tag, String.t()}
          | {:icon, String.t()}
          | {:image, String.t()}
          | {:renotify, String.t()}
          | {:requireInteraction, boolean}
          | {:silent, String.t()}
          | {:timestamp, String.t()}
          | {:title, String.t()}
          | {:vibrate, String.t()}
  @type key ::
          :permission
          | :actions
          | :badge
          | :body
          | :data
          | :dir
          | :lang
          | :tag
          | :icon
          | :image
          | :renotify
          | :requireInteraction
          | :silent
          | :timestamp
          | :title
          | :vibrate
  @type value :: permission | String.t() | map | boolean
  @type t :: %__MODULE__{
          fields: [field]
        }
  defstruct [
    :fields
  ]

  @spec new :: __MODULE__.t()
  def new do
    %__MODULE__{
      fields: []
    }
  end

  @spec add(t, key, value) :: t
  def add(web_notification, key, value) do
    %{web_notification | fields: [{key, value} | web_notification.fields]}
  end

  def to_map(web_notification) do
    Map.new(web_notification.fields)
  end
end
