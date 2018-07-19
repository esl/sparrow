defmodule Sparrow.H2ClientAdapter.Chatterbox do
  @moduledoc false

  @type connection_ref :: pid
  @type stream_id :: non_neg_integer
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type reason :: term

  @doc """
  Starts a new connection.
  """
  @spec open(String.t(), non_neg_integer, [any]) ::
          {:ok, connection_ref} | {:error, :ignore} | {:error, any}
  def open(domain, port, opts \\ []) do
    case :h2_client.start_link(:https, to_charlist(domain), port, opts) do
      :ignore -> {:error, :ignore}
      {:ok, connection_ref} -> {:ok, connection_ref}
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
          {:error, reason} | {:ok, stream_id}
  def post(conn, domain, path, headers, body) do
    headers = make_headers(:post, domain, path, headers, body)
    :h2_client.send_request(conn, headers, body)
  end

  @doc """
    Allows to read answer to notification.
  """
  @spec get_reponse(connection_ref, stream_id) :: {:ok, {headers, body}} | {:error, :not_ready}
  def get_reponse(conn, stream_id) do
    case :h2_connection.get_response(conn, stream_id) do
      {:ok, {headers, body}} ->
        {:ok, {headers, IO.iodata_to_binary(body)}}

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

  defp make_headers(method, domain, path, headers, body) do
    [
      {":method", String.upcase(Atom.to_string(method))},
      {":path", path},
      {":scheme", "https"},
      {":authority", domain},
      {"content-length", "#{byte_size(body)}"}
    ] ++ headers
  end
end
