defmodule Sparrow.H2Worker.RequestState do
  @moduledoc """
  Struct for requests internal representation.
  """
  alias Sparrow.H2Worker.Request

  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type from :: {pid, tag :: term} | :noreply
  @type timeout_reference :: reference
  @type response_part ::
          {:status, non_neg_integer} | {:headers, headers} | {:data, binary}
  @type response :: %{
          status: non_neg_integer | nil,
          headers: headers,
          data: iodata
        }

  @type t :: %__MODULE__{
          headers: headers,
          body: body,
          path: String.t(),
          from: from,
          timeout_reference: timeout_reference,
          response: response
        }

  defstruct [
    :headers,
    :body,
    :path,
    :timeout,
    :from,
    :timeout_reference,
    response: %{status: nil, headers: [], data: []}
  ]

  @spec new(Request.t(), from, timeout_reference) :: t
  def new(request, from, timeout_reference) do
    %__MODULE__{
      headers: request.headers,
      body: request.body,
      path: request.path,
      from: from,
      timeout_reference: timeout_reference
    }
  end

  @doc """
  Adds a part of a streamed response to the request.
  """
  @spec add_response_part(t, response_part) :: t
  def add_response_part(request = %__MODULE__{response: response}, part) do
    response =
      case part do
        {:status, status} ->
          %{response | status: status}

        {:headers, headers} ->
          %{response | headers: response.headers ++ headers}

        {:data, data} ->
          %{response | data: [response.data, data]}
      end

    %__MODULE__{request | response: response}
  end

  @doc """
  Builds the response out of the parts collected so far.
  """
  @spec response(t) :: {:ok, {headers, body}} | {:error, :not_ready}
  def response(%__MODULE__{response: %{status: nil}}) do
    {:error, :not_ready}
  end

  def response(%__MODULE__{response: response}) do
    headers = [
      {":status", Integer.to_string(response.status)} | response.headers
    ]

    {:ok, {headers, IO.iodata_to_binary(response.data)}}
  end
end
