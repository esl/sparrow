defmodule Sparrow.H2Worker.State do
  @moduledoc false
  @type connection_ref :: pid
  @type name :: :disconnected | :connected
  @type stream_id :: non_neg_integer
  @type requests :: %{required(stream_id) => %Sparrow.H2Worker.Request{}}
  @type config :: %Sparrow.H2Worker.Config{}

  @type t :: %__MODULE__{
          name: name,
          connection_ref: connection_ref | nil,
          requests: requests,
          config: config
        }

  defstruct [
    :name,
    :connection_ref,
    :requests,
    :config
  ]

  @doc """
  Creates new empty `Sparrow.H2Worker.State`.
  """
  @spec new(connection_ref | nil, requests, config) :: t
  def new(connection_ref, requests \\ %{}, config)

  def new(nil, requests, config) do
    %__MODULE__{
      name: :disconnected,
      connection_ref: nil,
      requests: requests,
      config: config
    }
  end

  def new(connection_ref, requests, config) do
    %__MODULE__{
      name: :connected,
      connection_ref: connection_ref,
      requests: requests,
      config: config
    }
  end

  @doc """
  Resets requests collection in `Sparrow.H2Worker.State`.
  """
  @spec reset_requests_collection(t) :: t
  def reset_requests_collection(state) do
    %__MODULE__{
      name: state.name,
      connection_ref: state.connection_ref,
      requests: %{},
      config: state.config
    }
  end

  @doc """
  Resets connection reference in `Sparrow.H2Worker.State`.
  """
  @spec reset_connection_ref(t) :: t
  def reset_connection_ref(state) do
    %__MODULE__{
      name: :disconnected,
      connection_ref: nil,
      requests: state.requests,
      config: state.config
    }
  end
end
