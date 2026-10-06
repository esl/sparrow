defmodule Sparrow.H2ClientAdapter.Finch do
  @moduledoc """
  Implements the client with Finch.

  Each connection is a separate Finch pool with a single HTTP/2 connection,
  identified by a unique tag. Finch reconnects it on its own.
  """
  @behaviour Sparrow.H2ClientAdapter

  require Logger

  @finch Sparrow.Finch

  # Errors reported before the request is sent to the server: the connection
  # is being (re)established, closed by the server, or has no free streams.
  @not_sent_errors [
    :pool_not_available,
    :disconnected,
    :connection_not_ready,
    :read_only,
    :unprocessed,
    :too_many_concurrent_requests
  ]

  @connect_timeout 5_000
  @connect_poll_interval 10

  @impl true
  def open(domain, port, opts \\ []) do
    # Finch connects in the background and doesn't report why it failed, so
    # the connection is checked first to fail fast with the actual reason.
    case check_connection(domain, port, opts) do
      :ok ->
        start_pool(domain, port, opts)

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

  @impl true
  def close(%{pool: pool}) do
    _ = Finch.stop_pool(@finch, pool)
    :ok
  end

  # Response is sent to the calling process in parts, see `handle_message/2`
  @impl true
  def post(%{pool: pool, base_url: base_url}, _domain, path, headers, body) do
    headers = [{"content-length", "#{byte_size(body)}"} | headers]

    ref =
      :post
      |> Finch.build(base_url <> path, headers, body, pool_tag: pool.tag)
      |> Finch.async_request(@finch)

    {:ok, ref}
  rescue
    # Pool is not registered while it's (re)connecting
    error in Finch.Error ->
      _ =
        Logger.debug("Error while sending HTTP request",
          what: :http_send,
          method: :post,
          status: :error,
          reason: inspect(error.reason)
        )

      if error.reason in @not_sent_errors do
        {:retry, error.reason}
      else
        {:error, error.reason}
      end
  end

  @impl true
  def ping(%{pool: pool}) do
    # `Finch.ping/2` waits for the pong, don't block the caller
    {:ok, _pid} =
      Task.start(fn ->
        with {:ok, _pid} <- Finch.find_pool(@finch, pool) do
          Finch.ping(@finch, pool)
        end
      end)

    :ok
  end

  @impl true
  def handle_message({{Finch.HTTP2.Pool, _} = ref, :done}, _conn) do
    {:done, ref}
  end

  def handle_message({{Finch.HTTP2.Pool, _} = ref, {:error, error}}, _conn) do
    case error_reason(error) do
      reason when reason in @not_sent_errors -> {:retry, ref, reason}
      reason -> {:error, ref, reason}
    end
  end

  def handle_message({{Finch.HTTP2.Pool, _} = ref, {kind, _} = part}, _conn)
      when kind in [:status, :headers, :data] do
    {:response_part, ref, part}
  end

  def handle_message(_message, _conn) do
    :unknown
  end

  defp check_connection(domain, port, opts) do
    connect_opts = [protocols: [:http2], transport_opts: opts]

    case Mint.HTTP.connect(:https, domain, port, connect_opts) do
      {:ok, conn} ->
        {:ok, _conn} = Mint.HTTP.close(conn)
        :ok

      {:error, error} ->
        {:error, error_reason(error)}
    end
  end

  defp start_pool(domain, port, opts) do
    base_url = "https://#{domain}:#{port}"
    pool = Finch.Pool.new(base_url, tag: make_ref())

    pool_opts = [
      protocols: [:http2],
      count: 1,
      conn_opts: [transport_opts: opts]
    ]

    :ok = Finch.start_pool(@finch, pool, pool_opts)

    case await_connected(pool, @connect_timeout) do
      {:ok, pid} ->
        {:ok, %{pool: pool, pid: pid, base_url: base_url}}

      {:error, reason} ->
        _ = Finch.stop_pool(@finch, pool)
        {:error, reason}
    end
  end

  defp error_reason(%{reason: reason}), do: reason
  defp error_reason(error), do: error

  # HTTP/2 pool registers only once it's connected
  defp await_connected(_pool, timeout) when timeout <= 0 do
    {:error, :timeout}
  end

  defp await_connected(pool, timeout) do
    case Finch.find_pool(@finch, pool) do
      {:ok, pid} ->
        {:ok, pid}

      :error ->
        Process.sleep(@connect_poll_interval)
        await_connected(pool, timeout - @connect_poll_interval)
    end
  end
end
