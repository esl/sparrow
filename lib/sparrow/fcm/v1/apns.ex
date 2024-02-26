defmodule Sparrow.FCM.V1.APNS do
  @moduledoc """
  Struct reflecting FCM object(ApnsConfig).
  See https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages?authuser=1#ApnsConfig
  FCM wrapper for `Sparrow.APNS.Notification`.
  """

  @type token_getter :: (-> {String.t(), String.t()})
  @type t :: %__MODULE__{
          notification: Sparrow.APNS.Notification.t(),
          token_getter: token_getter
        }
  defstruct [
    :notification,
    :token_getter
  ]

  @doc """
  Function to create new `Sparrow.FCM.V1.APNS`.

  ## Arguments

    * `notification` - APNS notification. See `Sparrow.APNS.Notification`.
    * `token_getter` - function returning authrization header. See `Sparrow.APNS.TokenBearer.get_token/1`.
  """
  @spec new(Sparrow.APNS.Notification.t(), token_getter) ::
          Sparrow.FCM.V1.APNS.t()
  def new(notification, token_getter) do
    %__MODULE__{
      notification: notification,
      token_getter: token_getter
    }
  end

  @doc """
    Function to transfer `Sparrow.FCM.V1.APNS` to map.
  """
  @spec to_map(t) :: map
  def to_map(apns) do
    %{
      :headers => Map.new([apns.token_getter.() | apns.notification.headers]),
      :payload => Sparrow.APNS.make_body(apns.notification)
    }
  end
end
