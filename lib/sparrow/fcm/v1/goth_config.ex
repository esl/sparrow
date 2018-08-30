defmodule Sparrow.FCM.V1.GothConfig do
  @moduledoc false
  use Goth.Config

  require Logger

  # TODO change to Application.get_env
  @json_path "sparrow_token.json"

  @spec init(any) :: {:ok, [{:json, String.t()}]}
  def init(_) do
    json =
      @json_path
      |> File.read!()

    {:ok, json: json}
  end
end
