defmodule Sparrow.FCM.V1.ProjectIdBearer do
  @moduledoc """
  Module providing FCM project id automaticly.
  """
  require Logger
  use GenServer
  @tab_name :fcm_project_ids

  @spec get_project_id(atom) :: String.t() | nil
  def get_project_id(h2_worker_pool) do
    case :ets.lookup(@tab_name, h2_worker_pool) do
      [{_, project_id}] -> project_id
      _ -> nil
    end
  end

  @spec add_project_id(Path.t(), atom) :: true
  def add_project_id(google_json_path, h2_worker_pool_name) do
    GenServer.call(
      __MODULE__,
      {:add_project_id, google_json_path, h2_worker_pool_name}
    )
  end

  def handle_call(
        {:add_project_id, google_json_path, h2_worker_pool_name},
        _from,
        _state
      ) do
    json = File.read!(google_json_path)

    _ =
      Logger.debug("Reading FCM config file",
        worker: :fcm_project_id_bearer,
        what: :read_json_config,
        result: :success
      )

    project_id =
      json
      |> Jason.decode!()
      |> Map.get("project_id")

    _ =
      Logger.debug("Extracting FCM project ID from config",
        worker: :fcm_project_id_bearer,
        what: :extract_project_id_from_json,
        project_id: inspect(project_id)
      )

    :ets.insert(@tab_name, {h2_worker_pool_name, project_id})
    {:reply, :ok, :ok}
  end

  @spec start_link :: GenServer.on_start()
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec init(any()) :: {:ok, :ok}
  def init(_) do
    @tab_name = :ets.new(@tab_name, [:set, :protected, :named_table])

    _ =
      Logger.info("Starting ProjectIdBearer",
        worker: :fcm_project_id_bearer,
        what: :init,
        result: :success
      )

    :telemetry.execute([:sparrow, :fcm, :project_id_bearer, :init], %{}, %{})

    {:ok, :ok}
  end

  @spec terminate(any, any) :: :ok
  def terminate(reason, _state) do
    _ =
      Logger.info("Shutting down ProjectIdBearer",
        worker: :fcm_project_id_bearer,
        what: :terminate,
        reason: inspect(reason)
      )

    :telemetry.execute(
      [:sparrow, :fcm, :project_id_bearer, :terminate],
      %{},
      %{}
    )
  end
end
