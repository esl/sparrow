defmodule Sparrow.H2Worker.RequestState do
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

  @doc !"""
       Struct for requests internal representation.
       """
  defstruct [
    :headers,
    :body,
    :path,
    :timeout,
    :from,
    :timeout_reference
  ]

  @spec new(%Sparrow.H2Worker.Request{}, from, timeout_reference) :: t
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
