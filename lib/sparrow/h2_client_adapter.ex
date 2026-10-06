defmodule Sparrow.H2ClientAdapter do
  @moduledoc false

  @default %{adapter: Sparrow.H2ClientAdapter.Finch}

  @type connection_ref :: term
  @type stream_id :: term
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type reason :: term
  @type response_part ::
          {:status, non_neg_integer} | {:headers, headers} | {:data, binary}
  @type event ::
          {:response_part, stream_id, response_part}
          | {:done, stream_id}
          | {:error, stream_id, reason}
          | {:retry, stream_id, reason}
          | :ok
          | :unknown

  @doc """
  Starts a new connection.
  """
  @callback open(String.t(), non_neg_integer, [any]) ::
              {:ok, connection_ref} | {:error, :ignore} | {:error, reason}

  @doc """
    Closes the connection.
  """
  @callback close(connection_ref) :: :ok

  @doc """
    Opens a new stream and sends request through it.
    DONT PASS PSEUDO HEADERS IN `headers`!!!

    Returns `{:retry, reason}` when the request was not sent, but it may
    succeed when sent again.
  """
  @callback post(connection_ref, String.t(), String.t(), headers, body) ::
              {:error, reason} | {:retry, reason} | {:ok, stream_id}

  @doc """
    Sends ping to given connection.
  """
  @callback ping(connection_ref) :: :ok

  @doc """
    Translates a message received by the process owning the connection.

    * `{:response_part, stream_id, part}` - a piece of the response
    * `{:done, stream_id}` - response is complete
    * `{:error, stream_id, reason}` - request failed
    * `{:retry, stream_id, reason}` - request was not sent, but it may succeed
      when sent again
    * `:ok` - message handled, nothing to do
    * `:unknown` - message doesn't come from the connection
  """
  @callback handle_message(message :: term, connection_ref) :: event

  def open(domain, port, opts \\ []) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.open(domain, port, opts)
  end

  def close(conn) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.close(conn)
  end

  def post(conn, domain, path, headers, body) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.post(conn, domain, path, headers, body)
  end

  def ping(conn) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.ping(conn)
  end

  def handle_message(message, conn) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.handle_message(message, conn)
  end
end
