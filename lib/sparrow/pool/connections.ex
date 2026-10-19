defmodule Sparrow.Pool.Connections do
  @moduledoc """
  Connections of a `Sparrow.Pool`, implemented with Finch.

  Each pool starts its own Finch instance, see `child_specs/1`. The config of
  the pool is the default of the instance, so it applies also to the Finch
  pools which Finch starts on its own.

  The connections are kept in a single Finch pool of HTTP/2 connections.
  Finch connects and reconnects them in the background, and keeps them alive
  with pings. Requests are spread over the connections evenly.
  """
  alias Finch.Pool.Strategy.RoundRobin
  alias Sparrow.Pool.Config

  @type connection_ref :: %{
          finch: atom,
          pool: Finch.Pool.t(),
          uri: URI.t(),
          strategy: {module, term}
        }
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()

  # Errors reported when the request was not delivered to the server: the
  # connection is being (re)established, closed by the server, or has no free
  # streams.
  @request_not_delivered_errors [
    # Finch
    :pool_not_available,
    :disconnected,
    :connection_not_ready,
    :read_only,
    # Mint
    :unprocessed,
    :too_many_concurrent_requests,
    {:server_closed_request, :refused_stream},
    # Socket, while the request is written
    :closed,
    :einval
  ]

  @doc """
  Specifications of processes needed by connections opened with given config.
  They are started before the connections are opened.
  """
  @spec child_specs(Config.t()) :: [Supervisor.child_spec() | map]
  def child_specs(config) do
    finch = finch_name(config)

    [
      Supervisor.child_spec(
        {Finch, name: finch, pools: %{default: pool_opts(config)}},
        id: finch
      ),
      # Not a process, it's run each time the instance is started
      %{id: {finch, :open}, start: {__MODULE__, :open, [config]}}
    ]
  end

  @doc """
  Reference to connections of the pool. They don't have to be running.
  """
  @spec connection_ref(Config.t()) :: connection_ref
  def connection_ref(config) do
    base_url = "https://#{config.domain}:#{config.port}"

    %{
      finch: finch_name(config),
      pool: Finch.Pool.new(base_url),
      # Parsed once, not with each request
      uri: URI.parse(base_url),
      strategy: {RoundRobin, RoundRobin.new()}
    }
  end

  @doc false
  # Starts the connections without waiting until they are established.
  # Otherwise they're started with the first request.
  @spec open(Config.t()) :: :ignore
  def open(config) do
    %{finch: finch, pool: pool} = connection_ref(config)
    :ok = Finch.start_pool(finch, pool, pool_opts(config))
    :ignore
  end

  @doc """
  Number of established connections.
  """
  @spec connected(connection_ref) :: non_neg_integer
  def connected(%{finch: finch, pool: pool}) do
    # HTTP/2 connection is registered only when it's established
    finch |> Registry.lookup(Finch.Pool.to_name(pool)) |> length()
  rescue
    # The instance is not running
    ArgumentError -> 0
  end

  @doc """
  Sends the request and waits for the response for at most `timeout`
  miliseconds. Status of the response is returned as `":status"` header.
  Pseudo-headers are added by Mint, don't pass them in `headers`.

  Returns `{:retry, reason}` when the request was not delivered, but it may
  succeed when sent again.
  """
  @spec request(connection_ref, String.t(), headers, body, timeout) ::
          {:ok, {headers, body}} | {:retry, term} | {:error, term}
  def request(conn, path, headers, body, timeout) do
    %{finch: finch, uri: uri, strategy: strategy} = conn
    headers = [{"content-length", "#{byte_size(body)}"} | headers]
    opts = [receive_timeout: max(timeout, 1), pool_strategy: strategy]

    :post
    |> Finch.build(%{uri | path: path}, headers, body)
    |> finch_request(finch, opts)
  end

  defp finch_request(request, finch, opts) do
    case Finch.request(request, finch, opts) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, {[{":status", Integer.to_string(status)} | headers], body}}

      {:error, error} ->
        error |> error_reason() |> request_error()
    end
  rescue
    # The Finch instance is not running, e.g. it's being restarted
    ArgumentError -> {:retry, :disconnected}
  catch
    # The request is handed over to the connection process with a call
    :exit, {:noproc, _call} -> {:retry, :disconnected}
    :exit, _reason -> {:error, :connection_lost}
  end

  defp request_error(reason) when reason in @request_not_delivered_errors do
    {:retry, reason}
  end

  defp request_error(:timeout), do: {:error, :request_timeout}

  # The request was sent, but the connection was lost before the response
  defp request_error(reason)
       when reason in [:connection_process_went_down, :connection_closed] do
    {:error, :connection_lost}
  end

  defp request_error(reason), do: {:error, reason}

  @doc """
  Name of the Finch instance used by the pool with given config.
  """
  @spec finch_name(Config.t()) :: atom
  def finch_name(%Config{name: name}) do
    Module.concat(Sparrow.Finch, name)
  end

  defp pool_opts(config) do
    [
      protocols: [:http2],
      count: config.connections,
      conn_opts: [transport_opts: Config.connection_tls_options(config)],
      http2: [
        # Sent by Finch after the connection was idle for that long
        ping_interval: config.ping_interval || :infinity,
        # Requests are sent only after the settings of the server are known
        wait_for_server_settings?: true
      ]
    ]
  end

  @doc false
  def error_reason(%{reason: reason}), do: reason
  def error_reason(error), do: error
end
