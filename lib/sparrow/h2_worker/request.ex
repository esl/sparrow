defmodule Sparrow.H2Worker.Request do
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type time_in_miliseconds :: non_neg_integer

  @type t :: %__MODULE__{
          headers: headers,
          body: body,
          path: String.t(),
          timeout: time_in_miliseconds
        }

  @doc !"""
       Struct to pass request to worker.
       """

  defstruct [
    :headers,
    :body,
    :path,
    :timeout
  ]

  @spec new(headers, body, String.t()) :: t
  def new(headers, body, path, timeout \\ 5_000) do
    %__MODULE__{headers: headers, body: body, path: path, timeout: timeout}
  end
end
