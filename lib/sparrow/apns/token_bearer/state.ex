defmodule Sparrow.APNS.TokenBearer.State do
  @moduledoc false

  @type t :: %__MODULE__{
          tokens: %{required(atom) => Sparrow.APNS.Token.t()},
          update_token_after: pos_integer
        }

  defstruct [
    :tokens,
    :update_token_after
  ]

  @spec new(%{required(atom) => Sparrow.APNS.Token.t()}, pos_integer) :: t
  def new(tokens, update_token_after) do
    %__MODULE__{
      tokens: tokens,
      update_token_after: update_token_after
    }
  end
end
