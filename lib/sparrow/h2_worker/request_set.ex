defmodule Sparrow.H2Worker.RequestSet do
  @moduledoc """
  Abstraction over requests collection.
  """
  alias Sparrow.H2Worker.RequestState

  @type stream_id :: non_neg_integer
  @type from :: {pid, tag :: term}
  @type requests :: %{required(stream_id) => %Sparrow.H2Worker.Request{}}

  @doc """
  Creates new requests collection.
  """
  @spec new() :: %{}
  def new do
    %{}
  end

  @doc """
  Adds request to requests collection.
  """
  @spec add(requests, stream_id, %RequestState{}) :: requests
  def add(
        other_requests,
        stream_id,
        new_request
      ) do
    Map.put(other_requests, stream_id, new_request)
  end

  @doc """
  Removes request from requests collection.
  """
  @spec remove(requests, stream_id) :: requests
  def remove(
        other_requests,
        stream_id
      ) do
    Map.delete(other_requests, stream_id)
  end

  @doc """
  Gets request from requests collection by `stream_id` as search key.
  """
  @spec get_request(requests, stream_id) ::
          {:ok, %RequestState{}} | {:error, :not_found}
  def get_request(requests, stream_id) do
    case Map.get(requests, stream_id, :not_found) do
      :not_found -> {:error, :not_found}
      request -> {:ok, request}
    end
  end
end
