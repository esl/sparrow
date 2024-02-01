defmodule Sparrow.H2Worker.Authentication.TokenBased do
  @moduledoc """
  Structure for token based authentication.
  Use to create Config for H2Worker.
  token_getter is a function returning tuple representing authentication header.

  ## Example 1

  import Sparrow.APNS.TokenBearer
  # For APNS token can be obtanin from `Sparrow.APNS.TokenBearer.get_token(token_id)`
  token_getter = fn -> {"authorization", "bearer \#{get_token(token_id)}"} end
  """
  @type token_getter :: (-> {String.t(), String.t()})
  @type t :: %__MODULE__{
          token_getter: token_getter
        }

  defstruct [
    :token_getter
  ]

  @spec new(token_getter) :: t
  def new(token_getter) do
    %__MODULE__{
      token_getter: token_getter
    }
  end
end
