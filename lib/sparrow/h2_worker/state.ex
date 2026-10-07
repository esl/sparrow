defmodule Sparrow.H2Worker.State do
  @moduledoc false
  @type connection_ref :: Sparrow.H2ClientAdapter.connection_ref()
  @type stream_id :: Sparrow.H2ClientAdapter.stream_id()
  @type requests :: Sparrow.H2Worker.RequestSet.requests()
  @type config :: %Sparrow.H2Worker.Config{}

  @type t :: %__MODULE__{
          connection_ref: connection_ref,
          requests: requests,
          config: config
        }

  defstruct [
    :connection_ref,
    :requests,
    :config
  ]

  @doc """
  Creates new empty `Sparrow.H2Worker.State`.
  """
  @spec new(connection_ref, requests, config) :: t
  def new(connection_ref, requests \\ %{}, config) do
    %__MODULE__{
      connection_ref: connection_ref,
      requests: requests,
      config: config
    }
  end
end
