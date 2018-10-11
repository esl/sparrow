defmodule Sparrow.APNS.AppConfigChecker do
  @moduledoc """
  Module chcecking if provided config file is valid.
  """

  @doc """
  Function chcecking if APNS authentication part of provided config is valid.
  """
  @spec check_authentication([[{atom, any}]], [[{atom, any}]]) :: boolean
  def check_authentication(pool_config, tokens) do
    case pool_config[:auth_type] do
      :certificate_based ->
        File.exists?(pool_config[:cert]) and File.exists?(pool_config[:key])

      :token_based ->
        pool_config[:token_id] in Enum.map(tokens, fn e -> e[:token_id] end)
    end
  end

  @doc """
  Function for getting list of raw pool configs.
  """
  @spec get_raw_pool_configs([{atom, any}]) :: [[{atom, any}]]
  def get_raw_pool_configs(raw_apns_config) do
    dev_configs = Keyword.get(raw_apns_config, :dev, [])
    prod_configs = Keyword.get(raw_apns_config, :prod, [])
    dev_configs ++ prod_configs
  end

  @doc """
  Fuction chcecking if token_ids duplicate and if APNS tokens are valid.
  """
  @spec validate_tokens([{atom, any}]) :: [
          [{atom, any}] | {:error, {:duplicated_token_id, atom}}
        ]
  def validate_tokens(tokens) do
    check_for_duplcates(tokens) ++
      for token <- tokens do
        validate_token(token)
      end
  end

  @spec validate_token([{atom, any}]) :: :ok | [{atom, any}]
  defp validate_token(token) do
    if Enum.all?([
         is_atom(token[:token_id]),
         is_binary(token[:key_id]),
         is_binary(token[:team_id]),
         File.exists?(token[:p8_file_path])
       ]) do
      :ok
    else
      token
    end
  end

  @spec check_for_duplcates([[{atom, any}]]) :: [
          {:error, {:duplicated_token_id, atom}}
        ]
  defp check_for_duplcates(tokens) do
    tokens
    |> Enum.map(fn token -> token[:token_id] end)
    |> (&(&1 -- Enum.uniq(&1))).()
    |> (&for(id <- &1, do: {:error, {:duplicated_token_id, id}})).()
  end
end
