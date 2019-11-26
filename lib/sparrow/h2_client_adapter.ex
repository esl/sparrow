defmodule Sparrow.H2ClientAdapter do
  @moduledoc false

  @type connection_ref :: pid
  @type stream_id :: non_neg_integer
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type reason :: term

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
  """
  @callback post(connection_ref, String.t(), String.t(), headers, body) ::
              {:error, byte()} | {:ok, stream_id}

  @doc """
    Allows to read answer to notification.
  """
  @callback get_response(connection_ref, stream_id) ::
              {:ok, {headers, body}} | {:error, :not_ready}

  @doc """
    Sends ping to given connection.
  """
  @callback ping(connection_ref) :: :ok

  def open(domain, port, opts \\ []) do
    adapter = Application.fetch_env!(:sparrow, __MODULE__)[:adapter]
    adapter.open(domain, port, opts)
  end

  def close(conn) do
    adapter = Application.fetch_env!(:sparrow, __MODULE__)[:adapter]
    adapter.close(conn)
  end

  def post(conn, domain, path, headers, body) do
    adapter = Application.fetch_env!(:sparrow, __MODULE__)[:adapter]
    adapter.post(conn, domain, path, headers, body)
  end

  def get_response(conn, stream_id) do
    adapter = Application.fetch_env!(:sparrow, __MODULE__)[:adapter]
    adapter.get_response(conn, stream_id)
  end

  def ping(conn) do
    adapter = Application.fetch_env!(:sparrow, __MODULE__)[:adapter]
    adapter.ping(conn)
  end
end
