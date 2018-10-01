defmodule Sparrow.APNSPoolSupervisor do
  @moduledoc """
  Supervises a single APNS workers pool.
  """
  use Supervisor

  @spec start_link(
          {String.t(), Sparrow.H2Worker.Pool.Config.t(), :dev | :prod, [atom]}
        ) :: Supervisor.on_start()
  def start_link(arg) do
    init(arg)
  end

  @spec init(
          {String.t(), Sparrow.H2Worker.Pool.Config.t(), :dev | :prod, [atom]}
        ) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init({pool_id, pool_config, pool_type, pool_tags}) do
    id = String.to_atom("Sparrow.H2Worker.Pool" <> pool_id)

    children = [
      %{
        id: id,
        start:
          {Sparrow.H2Worker.Pool, :start_link,
           [pool_config, pool_type, pool_tags]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
