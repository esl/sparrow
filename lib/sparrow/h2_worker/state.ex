defmodule Sparrow.H2Worker.State do
  @moduledoc false
  @type connection_ref :: Sparrow.H2ClientAdapter.connection_ref()
  @type config :: %Sparrow.H2Worker.Config{}

  @type t :: %__MODULE__{
          connection_ref: connection_ref,
          config: config
        }

  defstruct [
    :connection_ref,
    :config
  ]

  @doc """
  Creates new `Sparrow.H2Worker.State`.
  """
  @spec new(connection_ref, config) :: t
  def new(connection_ref, config) do
    %__MODULE__{
      connection_ref: connection_ref,
      config: config
    }
  end
end
