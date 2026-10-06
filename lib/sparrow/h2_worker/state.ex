defmodule Sparrow.H2Worker.State do
  @moduledoc false
  @type connection_ref :: Sparrow.H2ClientAdapter.connection_ref()
  @type stream_id :: Sparrow.H2ClientAdapter.stream_id()
  @type requests :: Sparrow.H2Worker.RequestSet.requests()
  @type config :: %Sparrow.H2Worker.Config{}

  @type t :: %__MODULE__{
          connection_ref: connection_ref | nil,
          requests: requests,
          config: config,
          restart_connection_timer: term() | nil
        }

  defstruct [
    :connection_ref,
    :requests,
    :config,
    :restart_connection_timer
  ]

  @doc """
  Creates new empty `Sparrow.H2Worker.State`.
  """
  @spec new(connection_ref | nil, requests, config) :: t
  def new(connection_ref, requests \\ %{}, config)

  def new(nil, requests, config) do
    %__MODULE__{
      connection_ref: nil,
      requests: requests,
      config: config,
      restart_connection_timer: nil
    }
  end

  def new(connection_ref, requests, config) do
    %__MODULE__{
      connection_ref: connection_ref,
      requests: requests,
      config: config,
      restart_connection_timer: nil
    }
  end

  @doc """
  Resets requests collection in `Sparrow.H2Worker.State`.
  """
  @spec reset_requests_collection(t) :: t
  def reset_requests_collection(state) do
    %__MODULE__{
      connection_ref: state.connection_ref,
      requests: %{},
      config: state.config,
      restart_connection_timer: state.restart_connection_timer
    }
  end

  @doc """
  Resets connection reference in `Sparrow.H2Worker.State`.
  """
  @spec reset_connection_ref(t) :: t
  def reset_connection_ref(state) do
    %__MODULE__{
      connection_ref: nil,
      requests: state.requests,
      config: state.config,
      restart_connection_timer: state.restart_connection_timer
    }
  end
end
