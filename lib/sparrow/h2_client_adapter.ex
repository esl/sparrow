defmodule Sparrow.H2ClientAdapter do
  @moduledoc false

  @default %{adapter: Sparrow.H2ClientAdapter.Finch}

  @type connection_ref :: term
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type reason :: term
  @type config :: Sparrow.H2Worker.Config.t()

  @doc """
  Specifications of processes needed by connections opened with given config.
  They are started before the connections are opened.
  """
  @callback child_specs(config) :: [Supervisor.child_spec() | map]

  @doc """
  Starts connections of a pool. It doesn't wait until they are established.
  """
  @callback open(config) :: {:ok, connection_ref}

  @doc """
  Number of established connections.
  """
  @callback connected(connection_ref) :: non_neg_integer

  @doc """
    Sends the request and waits for the response for at most `timeout`
    miliseconds. Status of the response is returned as `":status"` header.
    DONT PASS PSEUDO HEADERS IN `headers`!!!

    Returns `{:retry, reason}` when the request was not sent, but it may
    succeed when sent again.
  """
  @callback request(connection_ref, String.t(), headers, body, timeout) ::
              {:ok, {headers, body}} | {:retry, reason} | {:error, reason}

  def child_specs(config) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.child_specs(config)
  end

  def open(config) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.open(config)
  end

  def connected(conn) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.connected(conn)
  end

  def request(conn, path, headers, body, timeout) do
    adapter = Application.get_env(:sparrow, __MODULE__, @default)[:adapter]
    adapter.request(conn, path, headers, body, timeout)
  end
end
