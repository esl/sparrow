defmodule Sparrow.H2ClientAdapter.Finch do
  @moduledoc """
  Implements the client with Finch.

  Each pool of workers has its own Finch instance, see `child_specs/1`. Its
  default pool configuration is the configuration of the workers, so every
  Finch pool of the instance uses it, also the ones Finch starts on its own.

  Each connection is a separate Finch pool with a single HTTP/2 connection,
  identified by a tag. Finch connects and reconnects it in the background,
  and keeps it alive with pings.
  """
  @behaviour Sparrow.H2ClientAdapter

  alias Sparrow.H2Worker.Config

  require Logger

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
    pool = Finch.Pool.new(base_url, tag: connection_tag())

    # Doesn't wait for the connection
    :ok = Finch.start_pool(finch, pool, pool_opts(config))

    {:ok, %{finch: finch, pool: pool, base_url: base_url}}
  end

  @impl true
  def close(%{finch: finch, pool: pool}) do
    _ = Finch.stop_pool(finch, pool)
    :ok
  catch
    # The instance is already stopped
    :exit, _reason -> :ok
  end

  @impl true
  def connected?(%{finch: finch, pool: pool}) do
    # HTTP/2 pool is registered only when it's connected
    match?({:ok, _pid}, Finch.find_pool(finch, pool))
  end

  @impl true
  def request(conn, path, headers, body, timeout) do
    %{finch: finch, pool: pool, base_url: base_url} = conn
    headers = [{"content-length", "#{byte_size(body)}"} | headers]

    :post
    |> Finch.build(base_url <> path, headers, body, pool_tag: pool.tag)
    |> Finch.request(finch, receive_timeout: max(timeout, 1))
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
  Name of the Finch instance used by workers with given config.
  """
  @spec finch_name(Config.t()) :: atom
  def finch_name(%Config{pool_name: pool_name}) do
    Module.concat(Sparrow.Finch, pool_name)
  end

  @doc false
  def attach_telemetry(config) do
    finch = finch_name(config)
    handler_id = {__MODULE__, finch}

    worker_info = %{
      domain: config.domain,
      port: config.port,
      pool_type: config.pool_type,
      pool_name: config.pool_name,
      pool_tags: config.pool_tags
    }

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
      count: 1,
      conn_opts: [transport_opts: Config.connection_tls_options(config)],
      # Sent by Finch after the connection was idle for that long
      http2: [ping_interval: config.ping_interval || :infinity]
    ]
  end

  # Worker restarted by its pool has the same name, so it takes over
  # the connection of the previous one.
  defp connection_tag do
    case Process.info(self(), :registered_name) do
      {:registered_name, name} when is_atom(name) -> name
      _ -> make_ref()
    end
  end

  defp error_reason(%{reason: reason}), do: reason
  defp error_reason(error), do: error
end
