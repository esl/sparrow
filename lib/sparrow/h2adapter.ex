defmodule Sparrow.ChatterboxAdapter do
  @moduledoc false

  @type connection_ref :: pid
  @type client_ref :: term
  @type stream_id :: non_neg_integer
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()

  @doc """
  Starts a new connection.
  """
  @spec open(String.t(), non_neg_integer, [any]) ::
          {:ok, client_ref} | {:error, :ignore} | {:error, any}
  def open(uri, port, opts \\ []) do
    case :h2_client.start_link(:https, to_charlist(uri), port, opts) do
      :ignore -> {:error, :ignore}
      {:ok, client_ref} -> {:ok, client_ref}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
    Closes the connection.
  """
  @spec close(connection_ref) :: :ok
  def close(conn) do
    :h2_client.stop(conn)
  end

  @doc """
    Opens a new stream and sends request through it.
  """
  @spec post(connection_ref, String.t(), String.t(), headers, body) ::
          {:error, :unable_to_add_stream} | {:ok, stream_id}
  def post(conn, uri, path, headers, body) do
    case :h2_connection.new_stream(conn) do
      {:error, _code} ->
        {:error, :unable_to_add_stream}

      stream_id ->
        headers = make_headers(:post, uri, path, headers, body)
        :ok = :h2_connection.send_headers(conn, stream_id, headers)
        :ok = :h2_connection.send_body(conn, stream_id, body)
        {:ok, stream_id}
    end
  end

  @doc """
    Allows to read answer to notification.
  """
  @spec receive(connection_ref, stream_id) :: {:ok, headers, body} | {:error, :not_ready}
  def receive(conn, stream_id) do
    case :h2_connection.get_response(conn, stream_id) do
      {:ok, {headers, body}} ->
        {:ok, {headers, Enum.join(body)}}

      :not_ready ->
        {:error, :not_ready}
    end
  end

  @doc """
    Sends ping to given connection.
  """
  @spec ping(connection_ref) :: :ok
  def ping(conn) do
    :h2_client.send_ping(conn)
  end

  defp make_headers(method, uri, path, headers, body) do
    [
      {":method", String.upcase(Atom.to_string(method))},
      {":path", path},
      {":scheme", "https"},
      {":authority", uri},
      {"content-length", "#{byte_size(body)}"}
    ] ++ headers
  end
end
