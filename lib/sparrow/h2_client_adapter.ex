defmodule Sparrow.H2ClientAdapter do
  @moduledoc false

  @default %{adapter: Sparrow.H2ClientAdapter.Finch}

  @type connection_ref :: term
  @type stream_id :: term
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type reason :: term
  @type config :: Sparrow.H2Worker.Config.t()
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
  Specifications of processes needed by connections opened with given config.
  They are started before the workers of a pool.
  """
  @callback child_specs(config) :: [Supervisor.child_spec() | map]

  @doc """
  Starts a new connection. It doesn't wait until it's established.
  """
  @callback open(config) :: {:ok, connection_ref}

  @doc """
  Tells if the connection is established.
  """
  @callback connected?(connection_ref) :: boolean

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

  def child_specs(config) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.child_specs(config)
  end

  def open(config) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.open(config)
  end

  def connected?(conn) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.connected?(conn)
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
