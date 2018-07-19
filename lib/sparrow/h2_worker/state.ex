defmodule Sparrow.H2Worker.State do
  @type connection_ref :: pid
  @type stream_id :: non_neg_integer
  @type requests :: %{required(stream_id) => %Sparrow.H2Worker.Request{}}
  @type config :: %Sparrow.H2Worker.Config{}

  @type t :: %__MODULE__{
          connection_ref: connection_ref,
          requests: requests,
          config: config
        }

  @doc !"""
         Struct representing worker internal state.
       """
  defstruct [
    :connection_ref,
    :requests,
    :config
  ]

  @spec new(connection_ref, requests, config) :: t
  def new(connection_ref, requests \\ %{}, config) do
    %__MODULE__{
      connection_ref: connection_ref,
      requests: requests,
      config: config
    }
  end
end
