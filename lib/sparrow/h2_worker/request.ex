defmodule Sparrow.H2Worker.Request do
  @moduledoc """
  Struct to pass request to worker.
  """
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type time_in_miliseconds :: non_neg_integer

  @type t :: %__MODULE__{
          headers: headers,
          body: body,
          path: String.t(),
          timeout: time_in_miliseconds
        }

  defstruct [
    :headers,
    :body,
    :path,
    :timeout
  ]

  @doc """
  Function new creates request that can be passed to h2worker.

  ## Arguments

    * `headers` - http request headers
    * `body` - http request body
    * `path` - path to resource on server eg. for address "https://www.erlang-solutions.com/events.html" path is "/events.html"
    * `timeout` - request timeout (default 5_000)
  """
  @spec new(headers, body, String.t()) :: t
  def new(headers, body, path, timeout \\ 5_000) do
    %__MODULE__{headers: headers, body: body, path: path, timeout: timeout}
  end
end
