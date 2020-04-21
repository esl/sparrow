defmodule Sparrow.H2ClientAdapter.Chatterbox do
  @behaviour Sparrow.H2ClientAdapter

  @moduledoc false
  require Logger

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
  @impl true
  def open(domain, port, opts \\ []) do
    _ =
      Logger.debug("Opening HTTP/2 connection",
        what: :http_open,
        domain: domain,
        port: port,
        opts: inspect(opts)
      )

    case :h2_client.start(:https, to_charlist(domain), port, opts) do
      :ignore ->
        _ =
          Logger.debug("Error while opening HTTP/2 connection",
            what: :http_open,
            status: :error,
            domain: domain,
            port: port,
            reason: :ignore
          )

        {:error, :ignore}

      {:ok, connection_ref} ->
        _ =
          Logger.debug("HTTP/2 connection opened",
            what: :http_open,
            status: :error,
            domain: domain,
            port: port,
            connection: connection_ref
          )

        {:ok, connection_ref}

      {:error, reason} ->
        _ =
          Logger.debug("Error while opening HTTP/2 connection",
            what: :http_open,
            status: :error,
            domain: domain,
            port: port,
            reason: inspect(reason)
          )

        {:error, reason}
    end
  end

  @doc """
    Closes the connection.
  """
  @spec close(connection_ref) :: :ok
  @impl true
  def close(conn) do
    :h2_client.stop(conn)
  end

  @doc """
    Opens a new stream and sends request through it.
    DONT PASS PSEUDO HEADERS IN `headers`!!!
  """
  @spec post(connection_ref, String.t(), String.t(), headers, body) ::
          {:error, byte()} | {:ok, stream_id}
  @impl true
  def post(conn, domain, path, headers, body) do
    headers = make_headers(:post, domain, path, headers, body)

    try do
      :h2_client.send_request(conn, headers, body)
    catch
      # We may loose connection mid-request
      :exit, reason ->
        _ =
          Logger.debug("Error while sending HTTP request",
            what: :http_send,
            method: :post,
            headers: headers,
            body: inspect(body),
            status: :error,
            reason: inspect(reason)
          )

        {:error, :connection_lost}
    end
  end

  @doc """
    Allows to read answer to notification.
  """
  @spec get_response(connection_ref, stream_id) ::
          {:ok, {headers, body}} | {:error, :not_ready}
  @impl true
  def get_response(conn, stream_id) do
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
  @impl true
  def ping(conn) do
    :h2_client.send_ping(conn)
  catch
    # We may loose connection mid-request
    :exit, reason ->
      _ =
        Logger.debug("Error while sending HTTP ping",
          what: :http_send,
          method: :ping,
          status: :error,
          reason: inspect(reason)
        )

      {:error, :connection_lost}
  end

  @spec make_headers(:post, String.t(), String.t(), headers, body) :: headers
  defp make_headers(method, domain, path, headers, body) do
    [
      {":method", String.upcase(Atom.to_string(method))},
      {":path", path},
      {":scheme", "https"},
      {":authority", domain},
      {"content-length", "#{byte_size(body)}"}
      | headers
    ]
  end
end
