defmodule Sparrow.FCM.V1.ProjectIdBearer do
  @moduledoc """
  Module providing FCM project id automaticly.
  """
  require Logger
  use GenServer
  @tab_name :fcm_project_ids

  @spec get_project_id(atom) :: String.t() | nil
  def get_project_id(h2_worker_pool) do
    @tab_name
    |> :ets.lookup(h2_worker_pool)
    |> (fn [{_, project_id}] -> project_id end).()
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
      Logger.debug(fn ->
        "worker=fcm_project_id_bearer, action=read_json, result=success"
      end)

    project_id =
      json
      |> Jason.decode!()
      |> Map.get("project_id")

    _ =
      Logger.debug(fn ->
        "worker=fcm_project_id_bearer, action=exteract_project_id_from_json, project_id=#{
          inspect(project_id)
        }"
      end)

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
      Logger.info(fn ->
        "worker=fcm_project_id_bearer, action=init, result=success"
      end)

    {:ok, :ok}
  end
end
