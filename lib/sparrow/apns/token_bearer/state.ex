defmodule Sparrow.APNS.TokenBearer.State do
  @moduledoc false

  @type t :: %__MODULE__{
          key_id: String.t(),
          team_id: String.t(),
          p8_file_path: String.t(),
          refresh_token_time: non_neg_integer
        }

  defstruct [
    :key_id,
    :team_id,
    :p8_file_path,
    :refresh_token_time
  ]

  @doc """
  Creates new token bearer state.
  """
  @spec new(String.t(), String.t(), String.t(), non_neg_integer) :: t
  def new(key_id, team_id, p8_file_path, refresh_token_time) do
    %__MODULE__{
      key_id: key_id,
      team_id: team_id,
      p8_file_path: p8_file_path,
      refresh_token_time: refresh_token_time
    }
  end
end
