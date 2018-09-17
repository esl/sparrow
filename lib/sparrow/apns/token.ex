defmodule Sparrow.APNS.Token do
  @moduledoc """
  Struct to init argument for APNS token bearer.
  """

  @type t :: %__MODULE__{
          key_id: String.t(),
          team_id: String.t(),
          p8_file_path: String.t()
        }

  defstruct [
    :key_id,
    :team_id,
    :p8_file_path
  ]

  @doc """
  Creates new token.

  ## Arguments

    * `key_id` - APNS key ID
    * `team_id` - 10-character Team ID you use for developing your company’s apps.
    * `p8_file_path` - file path to APNs authentication token signing key to generate the tokens

  ## How to obtain key (content of file under p8_file_path) and `key_id`?

  Read: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token_based_connection_to_apns

  ## How to obtain `team_id`?

  Read: https://www.mobiloud.com/help/knowledge-base/ios-app-transfer/

  ## How often should I refresh token?

  Read: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token_based_connection_to_apns
  Section: Refresh Your Token Regularly
  """
  @spec new(String.t(), String.t(), String.t()) :: t
  def new(
        key_id,
        team_id,
        p8_file_path
      ) do
    %__MODULE__{
      key_id: key_id,
      team_id: team_id,
      p8_file_path: p8_file_path
    }
  end
end
