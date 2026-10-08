defmodule Sparrow.H2Worker.RequestSet do
  @moduledoc """
  Abstraction over requests collection.
  """
  alias Sparrow.H2Worker.RequestState

  @type stream_id :: term
  @type from :: {pid, tag :: term}
  @type requests :: %{required(stream_id) => RequestState.t()}

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
  @spec add(requests, stream_id, RequestState.t()) :: requests
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
  Removes request from requests collection and returns it,
  `nil` is returned when there is no such request.
  """
  @spec pop(requests, stream_id) :: {RequestState.t() | nil, requests}
  def pop(requests, stream_id) do
    Map.pop(requests, stream_id)
  end

  @doc """
  Gets request from requests collection by `stream_id` as search key.
  """
  @spec get_request(requests, stream_id) ::
          {:ok, RequestState.t()} | {:error, :not_found}
  def get_request(requests, stream_id) do
    case Map.get(requests, stream_id, :not_found) do
      :not_found -> {:error, :not_found}
      request -> {:ok, request}
    end
  end

  @doc """
  Adds a part of a streamed response to the request with given `stream_id`.
  Does nothing when there is no such request.
  """
  @spec add_response_part(requests, stream_id, RequestState.response_part()) ::
          requests
  def add_response_part(requests, stream_id, part) do
    case requests do
      %{^stream_id => request} ->
        %{requests | stream_id => RequestState.add_response_part(request, part)}

      _ ->
        requests
    end
  end
end
