defmodule Sparrow.H2ClientAdapter.Finch do
  @moduledoc """
  Implements the client with Finch.
  """
  @behaviour Sparrow.H2ClientAdapter

  @finch Sparrow.Finch

  @connect_timeout 5_000
  @connect_poll_interval 10

  @impl true
  def open(domain, port, opts \\ []) do
    base_url = "https://#{domain}:#{port}"
    pool = Finch.Pool.new(base_url, tag: make_ref())

    opts = [
      protocols: [:http2],
      count: 1,
      conn_opts: [transport_opts: opts]
    ]

    :ok = Finch.start_pool(@finch, pool, opts)

    case await_connected(pool, @connect_timeout) do
      {:ok, pid} ->
        {:ok, %{pool: pool, pid: pid, base_url: base_url}}

      {:error, :timeout} ->
        _ = Finch.stop_pool(@finch, pool)

        {:error, :timeout}
    end
  end

  @impl true
  def close(%{pool: pool}) do
    _ = Finch.stop_pool(@finch, pool)
    :ok
  end

  @impl true
  def post(%{base_url: base_url}, _domain, path, headers, body) do
    ref =
      :post
      |> Finch.build(Path.join(base_url, path), headers, body)
      |> Finch.async_request(@finch)

    {:ok, ref}
  end

  @impl true
  def get_response(_connection_ref, _stream_id) do
    :ok
  end

  @impl true
  def ping(_connection_ref) do
    :ok
  end

  # Internal

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
