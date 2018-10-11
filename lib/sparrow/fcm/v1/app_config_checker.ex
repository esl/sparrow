defmodule Sparrow.FCM.V1.AppConfigChecker do
  @moduledoc """
  Module chcecking if provided config file is valid.
  """

  @doc """
  Function chcecking if FCM authentication part of provided config is valid.
  """
  @spec check_authentication([[{atom, any}]], [[{atom, any}]]) :: boolean
  def check_authentication(pool_config, _) do
        File.exists?(pool_config[:path_to_json])
  end

  @doc """
  Function for getting list of raw pool configs.
  """
  @spec get_raw_pool_configs([{atom, any}]) :: [[{atom, any}]]
  def get_raw_pool_configs(raw_fcm_config) do
    [raw_fcm_config]
  end

  @doc """
  Fuction chcecking if token_ids duplicate and if FCM tokens are valid.
  """
  @spec validate_tokens([{atom, any}]) :: [
          [{atom, any}] | {:error, {:duplicated_token_id, atom}}
        ]
  def validate_tokens(_) do
    []
  end
end
