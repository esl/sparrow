defmodule Sparrow.H2ClientAdapter.Finch do
  @moduledoc """
  Implements the client with Finch.

  Each pool has its own Finch instance, see `child_specs/1`. Its default pool
  configuration is the configuration of the pool, so every Finch pool of the
  instance uses it, also the ones Finch starts on its own.

  Connections of a pool are a single Finch pool of HTTP/2 connections. Finch
  connects and reconnects them in the background, and keeps them alive with
  pings. Requests are spread over the connections evenly.
  """
  @behaviour Sparrow.H2ClientAdapter

  alias Finch.Pool.Strategy.RoundRobin
  alias Sparrow.H2Worker.Config

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

  @impl true
  def child_specs(config) do
    finch = finch_name(config)

    [
      Supervisor.child_spec(
        {Finch, name: finch, pools: %{default: pool_opts(config)}},
        id: finch
      ),
      # Not a process, attaches the handler each time the instance is started
      %{
        id: {finch, :telemetry},
        start: {__MODULE__, :attach_telemetry, [config]},
        restart: :temporary
      }
    ]
  end

  @impl true
  def open(config) do
    finch = finch_name(config)
    base_url = "https://#{config.domain}:#{config.port}"
    pool = Finch.Pool.new(base_url)

    # Doesn't wait for the connections
    :ok = Finch.start_pool(finch, pool, pool_opts(config))

    {:ok,
     %{
       finch: finch,
       pool: pool,
       base_url: base_url,
       strategy: {RoundRobin, RoundRobin.new()}
     }}
  end

  @impl true
  def connected(%{finch: finch, pool: pool}) do
    # HTTP/2 connection is registered only when it's established
    finch |> Registry.lookup(Finch.Pool.to_name(pool)) |> length()
  rescue
    # The instance is not running
    ArgumentError -> 0
  end

  @impl true
  def request(conn, path, headers, body, timeout) do
    %{finch: finch, base_url: base_url, strategy: strategy} = conn
    headers = [{"content-length", "#{byte_size(body)}"} | headers]
    opts = [receive_timeout: max(timeout, 1), pool_strategy: strategy]

    :post
    |> Finch.build(base_url <> path, headers, body)
    |> Finch.request(finch, opts)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, {[{":status", Integer.to_string(status)} | headers], body}}

      {:error, error} ->
        request_error(error_reason(error))
    end
  catch
    # The request is handed over to the connection process with a call
    :exit, {:noproc, _call} -> {:retry, :disconnected}
    :exit, _reason -> {:error, :connection_lost}
  end

  defp request_error(reason) when reason in @not_sent_errors do
    {:retry, reason}
  end

  defp request_error(:timeout), do: {:error, :request_timeout}

  defp request_error(:connection_process_went_down) do
    {:error, :connection_lost}
  end

  defp request_error(reason), do: {:error, reason}

  @doc """
  Name of the Finch instance used by the pool with given config.
  """
  @spec finch_name(Config.t()) :: atom
  def finch_name(%Config{pool_name: pool_name}) do
    Module.concat(Sparrow.Finch, pool_name)
  end

  @doc false
  def attach_telemetry(config) do
    finch = finch_name(config)
    handler_id = {__MODULE__, finch}

    worker_info = Config.pool_info(config)

    _ = :telemetry.detach(handler_id)

    :ok =
      :telemetry.attach(
        handler_id,
        [:finch, :connect, :stop],
        &__MODULE__.handle_connect_event/4,
        %{finch: finch, worker_info: worker_info}
      )

    :ignore
  end

  @doc false
  def handle_connect_event(
        _event,
        _measurements,
        metadata = %{name: finch},
        %{finch: finch, worker_info: worker_info}
      ) do
    case metadata do
      %{error: error} ->
        :telemetry.execute(
          [:sparrow, :h2_worker, :conn_fail],
          %{},
          Map.put(worker_info, :reason, error_reason(error))
        )

      _ ->
        :telemetry.execute(
          [:sparrow, :h2_worker, :conn_success],
          %{},
          worker_info
        )
    end
  end

  def handle_connect_event(_event, _measurements, _metadata, _config) do
    :ok
  end

  defp pool_opts(config) do
    [
      protocols: [:http2],
      count: config.connections,
      conn_opts: [transport_opts: Config.connection_tls_options(config)],
      # Sent by Finch after the connection was idle for that long
      http2: [ping_interval: config.ping_interval || :infinity]
    ]
  end

  defp error_reason(%{reason: reason}), do: reason
  defp error_reason(error), do: error
end
