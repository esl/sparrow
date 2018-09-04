defmodule Sparrow.FCM.V1.Android.Notification do
  @moduledoc false
  @type key ::
          :title
          | :body
          | :icon
          | :color
          | :sound
          | :tag
          | :click_action
          | :body_loc_key
          | :"body_loc_args[]"
          | :title_loc_key
          | :"title_loc_args[]"
  @type t :: %__MODULE__{fields: [{key, value :: String.t()}]}

  defstruct [:fields]

  @spec new() :: t
  def new do
    %__MODULE__{fields: []}
  end

  @spec add(__MODULE__.t(), key, value :: String.t()) :: __MODULE__.t()
  def add(notification, key, value) do
    %__MODULE__{fields: [{key, value} | notification.fields]}
  end

  @spec to_map(__MODULE__.t()) :: map
  def to_map(android_notification) do
    Map.new(android_notification.fields)
  end
end
