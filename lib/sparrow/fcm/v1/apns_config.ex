defmodule Sparrow.FCM.V1.APNSConfig do
  @moduledoc """
  Struct reflecting FCM object(ApnsConfig).
  Reflects https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#ApnsConfig
  """

  @type token_getter :: (() -> {String.t(), String.t()})
  @type t :: %__MODULE__{
          notification: Sparrow.APNS.Notification.t(),
          token_getter: token_getter
        }
  defstruct [
    :notification,
    :token_getter
  ]

  @spec new(Sparrow.APNS.Notification.t(), token_getter) ::
          Sparrow.FCM.V1.APNSConfig.t()
  def new(notification, token_getter) do
    %__MODULE__{
      notification: notification,
      token_getter: token_getter
    }
  end

  @spec to_map(t) :: map
  def to_map(apns_config) do
    %{
      :headers =>
        Map.new([apns_config.token_getter.() | apns_config.notification.headers]),
      :payload => Sparrow.APNS.make_body(apns_config.notification)
    }
  end
end
