defmodule Sparrow.APNS.Supervisor do
  @moduledoc """
  Main APNS supervisor.
  Supervises APNS tokens bearer and pool supervisors.
  """
  use Supervisor

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec init(Keyword.t()) ::
          {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(raw_apns_config) do
    tokens = get_apns_tokens(raw_apns_config)

    children = [
      {Sparrow.APNS.Pool.Supervisor, raw_apns_config},
      {Sparrow.APNS.TokenBearer, tokens}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @spec get_apns_tokens(Keyword.t()) :: %{
          required(atom) => Sparrow.APNS.Token.t()
        }
  defp get_apns_tokens(raw_apns_config) do
    token_configs = Keyword.get(raw_apns_config, :tokens, [])

    for token_config <- token_configs, into: %{} do
      get_apns_token(token_config)
    end
  end

  @spec get_apns_token(Keyword.t()) :: {atom, Sparrow.APNS.Token.t()}
  defp get_apns_token(token_config) do
    token_id = Keyword.get(token_config, :token_id)
    team_id = Keyword.get(token_config, :team_id)
    key_id = Keyword.get(token_config, :key_id)
    p8_file_path = Keyword.get(token_config, :p8_file_path)
    {token_id, Sparrow.APNS.Token.new(key_id, team_id, p8_file_path)}
  end
end
