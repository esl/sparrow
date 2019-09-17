defmodule Sparrow.FCM.V1.Supervisor do
  @moduledoc """
  Main FCM supervisor.
  Supervises FCM token bearer and pool supervisor.
  """
  use Supervisor

  @spec start_link([Keyword.t()]) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec init([Keyword.t()]) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
  def init(raw_fcm_config) do
    children = [
      %{
        id: Sparrow.FCM.V1.TokenBearer,
        start:
          {Sparrow.FCM.V1.TokenBearer, :start_link,
           [raw_fcm_config]}
      },
      Sparrow.FCM.V1.ProjectIdBearer,
      {Sparrow.FCM.V1.Pool.Supervisor, raw_fcm_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
