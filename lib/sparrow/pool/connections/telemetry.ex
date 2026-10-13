defmodule Sparrow.Pool.Connections.Telemetry do
  @moduledoc false
  # Keeps the handler reporting connections of a pool attached as long as
  # the pool is running. The handler is called for connections of all Finch
  # instances, so it's detached when the pool is stopped.
  use GenServer

  alias Sparrow.Pool.Connections

  @spec start_link(Sparrow.Pool.Config.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl true
  def init(config) do
    # To detach the handler also when the pool is stopped by its supervisor
    Process.flag(:trap_exit, true)
    {:ok, Connections.attach_telemetry(config)}
  end

  @impl true
  def terminate(_reason, handler_id) do
    Connections.detach_telemetry(handler_id)
  end
end
