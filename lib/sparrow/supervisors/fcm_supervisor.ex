defmodule Sparrow.FCMSupervisor do
  @moduledoc """
  Main FCM supervisor.
  Supervises FCM token bearer and pool supervisor.
  """
  use Supervisor

  @spec start_link([{atom, any}]) :: Supervisor.on_start()
  def start_link(arg) do
    init(arg)
  end

  @spec init(any) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(raw_config) do
    children = [
      %{
        id: Sparrow.FCM.V1.TokenBearer,
        start:
          {Sparrow.FCM.V1.TokenBearer, :start_link, [raw_config[:path_to_json]]}
      },
      %{
        id: Sparrow.FCMPoolSupervisor,
        start: {Sparrow.FCMPoolSupervisor, :start_link, [raw_config]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
