defmodule Sparrow.H2Worker.Pool do
  @moduledoc """
  Module providing functions to work on (`Sparrow.H2Worker`) worker pools and not single workers.
  """
  @type request :: Sparrow.H2Worker.Request.t()
  @type strategy ::
          :best_worker
          | :random_worker
          | :next_worker
          | :available_worker
          | :next_available_worker
  @type body :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type reason :: atom
  @type worker_config :: Sparrow.H2Worker.Config.t()
  @type pool_type :: Sparrow.PoolsWarden.pool_type()
  @doc """
  Sends the request and, if `is_sync` is `true`, awaits the response.

  ## Arguments

    * `worker_pool` - H2Workers pool name you want to send message with
    * `request` - HTTP2 request, see Sparrow.H2Worker.Request
    * `is_sync` - if `is_sync` is `true`, awaits the response, otherwize returns `:ok`
    * `genserver_timeout` -  timeout of genserver call, works only if `is_sync` is `true`
    * `worker_choice_strategy` - worker selection strategy. See https://github.com/inaka/worker_pool section: "Choosing a Strategy"
  """
  require Logger

  @spec send_request(atom, request, boolean(), non_neg_integer, strategy) ::
          {:error, :connection_lost}
          | {:ok, {headers, body}}
          | {:error, :request_timeout}
          | {:error, :not_ready}
          | {:error, reason}
          | :ok
  def send_request(
        worker_pool,
        request,
        is_sync \\ true,
        genserver_timeout \\ 60_000,
        worker_choice_strategy \\ :random_worker
      )

  def send_request(worker_pool, request, false, _, strategy) do
    _ =
      Logger.debug("Dispatching request to worker pool",
        worker_pool: inspect(worker_pool),
        request: request,
        type: :cast
      )

    :wpool.cast(worker_pool, {:send_request, request}, strategy)
  end

  def send_request(worker_pool, request, true, genserver_timeout, strategy) do
    _ =
      Logger.debug("Dispatching request to worker pool",
        worker_pool: inspect(worker_pool),
        request: request,
        type: :call
      )

    :wpool.call(
      worker_pool,
      {:send_request, request},
      strategy,
      genserver_timeout
    )
  end

  @doc """
  Function to start pool.
  """
  @spec start_unregistered(Sparrow.H2Worker.Pool.Config.t(), pool_type, [atom]) ::
          {:error, any} | {:ok, pid}
  def start_unregistered(config, pool_type, tags \\ []) do
    # We add pool information to worker config only for the telemetry events
    worker_config_with_pool = %Sparrow.H2Worker.Config{
      config.workers_config
      | pool_type: pool_type,
        pool_name: config.pool_name,
        pool_tags: tags
    }

    :wpool.start_pool(
      config.pool_name,
      [
        {:workers, config.worker_num},
        {:worker, {Sparrow.H2Worker, worker_config_with_pool}}
        | config.raw_opts
      ]
    )
  end

  @doc """
  Function to start pool and "register" it in pool warden.
  """
  @spec start_link(Sparrow.H2Worker.Pool.Config.t(), pool_type, [atom]) ::
          {:ok, pid}
  def start_link(config, pool_type, tags \\ []) do
    pool_name = config.pool_name
    {:ok, pid} = start_unregistered(config, pool_type, tags)
    Sparrow.PoolsWarden.add_new_pool(pid, pool_type, pool_name, tags)
    {:ok, pid}
  end
end
