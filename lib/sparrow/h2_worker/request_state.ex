defmodule Sparrow.H2Worker.RequestState do
  @moduledoc """
  Struct for requests internal representation.
  """
  alias Sparrow.H2Worker.Request

  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type from :: {pid, tag :: term} | :noreply
  @type timeout_reference :: reference

  @type t :: %__MODULE__{
          headers: headers,
          body: body,
          path: String.t(),
          from: from,
          timeout_reference: timeout_reference
        }

  defstruct [
    :headers,
    :body,
    :path,
    :timeout,
    :from,
    :timeout_reference
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
end
