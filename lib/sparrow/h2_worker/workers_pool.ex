defmodule Sparrow.H2Worker.WorkersPool do
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
  @type reason :: any
  @type config :: Sparrow.H2Worker.Config.t()

  @doc """
  Sends the request and, if `is_sync` is `true`, awaits the response.

  ## Arguments

    * `worker_pool` - H2Workers pool name you want to send message with
    * `request` - HTTP2 request, see Sparrow.H2Worker.Request
    * `is_sync` - if `is_sync` is `true`, awaits the response, otherwize returns `:ok`
    * `genserver_timeout` -  timeout of genserver call, works only if `is_sync` is `true`
  """
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
    :wpool.cast(worker_pool, {:send_request, request}, strategy)
  end

  def send_request(worker_pool, request, true, genserver_timeout, strategy) do
    :wpool.call(
      worker_pool,
      {:send_request, request},
      strategy,
      genserver_timeout
    )
  end

  @spec start_link(wpool_name :: atom, config, non_neg_integer, [{atom, any}]) ::
          {:error, any} | {:ok, pid}
  def start_link(
        wpool_name,
        workers_config,
        workers_number \\ 3,
        wpool_config \\ []
      ) do
    _ = :wpool.start()

    :wpool.start_pool(
      wpool_name,
      [
        {:workers, workers_number},
        {:worker, {Sparrow.H2Worker, workers_config}}
        | wpool_config
      ]
    )
  end
end
