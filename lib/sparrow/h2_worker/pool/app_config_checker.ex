defmodule Sparrow.H2Worker.Pool.AppConfigChecker do
  @moduledoc """
  Module chcecking if provided config file is valid.
  """

  @doc """
  Function chcecking if Worker and Pool parts of provided config are valid.
  Returns list of configs with found errors, if all configs are correct empty list is returned.
  """
  @spec validate_config([{atom, any}], atom) :: [
          [{atom, any}] | {:error, {:duplicated_token_id, atom}}
        ]
  def validate_config(raw_config, auth_checker) do
    tokens = Keyword.get(raw_config, :tokens, [])

    raw_config
    |> auth_checker.get_raw_pool_configs()
    |> validate_configs(tokens, auth_checker)
    |> (&(&1 ++ auth_checker.validate_tokens(tokens))).()
    |> Enum.filter(fn
      :ok -> false
      _wrong_config -> true
    end)
  end

  @spec validate_configs([{atom, any}], [[{atom, any}]], atom) :: [{atom, any}]
  defp validate_configs([], _, _), do: []

  defp validate_configs(pool_configs, tokens, auth_checker) do
    for pool_config <- pool_configs do
      chceks = [
        auth_checker.check_authentication(pool_config, tokens),
        chceck_tags(pool_config),
        chceck_pool_name(pool_config)
        | for property <- [
                :port,
                :ping_interval,
                :reconnect_attempts,
                :worker_num
              ] do
            chceck_non_neg_integer(pool_config, property)
          end
      ]

      if Enum.all?(chceks) do
        :ok
      else
        pool_config
      end
    end
  end

  @spec chceck_non_neg_integer([{atom, any}], atom) :: boolean
  defp chceck_non_neg_integer(pool_config, property) do
    pool_config
    |> Keyword.get(property, 1)
    |> is_non_neg_integer()
  end

  @spec chceck_tags([{atom, any}]) :: boolean
  defp chceck_tags(pool_config) do
    pool_config
    |> Keyword.get(:tags, [])
    |> Enum.all?(&is_atom/1)
  end

  @spec chceck_pool_name([{atom, any}]) :: boolean
  defp chceck_pool_name(pool_config) do
    pool_config
    |> Keyword.get(:pool_name, :ok)
    |> is_atom
  end

  @spec is_non_neg_integer(any) :: boolean
  defp is_non_neg_integer(x) when is_integer(x), do: x > 0
  defp is_non_neg_integer(_), do: false
end
