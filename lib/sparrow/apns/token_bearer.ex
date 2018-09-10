defmodule Sparrow.APNS.TokenBearer do
  @moduledoc """
  Module providing APNS token. Token is regenerated every `refresh_token_time` miliseconds.
  """

  use GenServer
  require Logger

  @type bearer_token :: Joken.bearer_token()
  @type claims :: Joken.claims()

  @tab_name :sparrow_apns_token_bearer
  @apns_jwt_alg "ES256"

  @doc """
  Returns APNS token for token based authentication.
  """
  @spec get_token() :: String.t()
  def get_token do
    :ets.lookup_element(@tab_name, :apns_token, 2)
  end

  @spec init(Sparrow.APNS.Token.t()) ::
          {:ok, Sparrow.APNS.TokenBearer.State.t()}
  def init(token) do
    state =
      Sparrow.APNS.TokenBearer.State.new(
        token.key_id,
        token.team_id,
        token.p8_file_path,
        token.refresh_token_time
      )

    @tab_name = :ets.new(@tab_name, [:set, :protected, :named_table])
    update_token(state)

    _ =
      Logger.info(fn ->
        "worker=apns_token_bearer, action=init, result=success"
      end)

    {:ok, state}
  end

  @spec terminate(any, Sparrow.APNS.TokenBearer.State.t()) :: :ok
  def terminate(reason, _state) do
    ets_del = :ets.delete(@tab_name)

    _ =
      Logger.info(fn ->
        "worker=apns_token_bearer, action=terminate, reason=#{inspect(reason)}, ets_delate_result=#{
          inspect(ets_del)
        }"
      end)
  end

  @spec handle_info(:update_token | any, Sparrow.APNS.TokenBearer.State.t()) ::
          {:noreply, Sparrow.APNS.TokenBearer.State.t()}
  def handle_info(:update_token, state) do
    update_token(state)
    _ = Logger.debug(fn -> "worker=apns_token_bearer, action=token_update" end)
    {:noreply, state}
  end

  def handle_info(unknown, state) do
    _ =
      Logger.warn(fn ->
        "worker=apns_token_bearer, Unknown info #{inspect(unknown)}"
      end)

    {:noreply, state}
  end

  @spec update_token(Sparrow.APNS.TokenBearer.State.t()) :: true
  defp update_token(state) do
    state.refresh_token_time
    |> schedule_message_after(:update_token)

    set_new_token(state)
  end

  @spec set_new_token(Sparrow.APNS.TokenBearer.State.t()) :: true
  defp set_new_token(state) do
    {:ok, token, _} =
      new_jwt_token(state.key_id, state.team_id, state.p8_file_path)

    :ets.insert(@tab_name, {:apns_token, token})
  end

  @spec new_jwt_token(String.t(), String.t(), String.t()) ::
          {:error, reason :: any} | {:ok, bearer_token, claims}
  defp new_jwt_token(key_id, team_id, p8_file_path) do
    signer = new_signer(@apns_jwt_alg, key_id, p8_file_path)

    %{}
    |> Map.put("iat", %Joken.Claim{
      generate: fn -> Joken.CurrentTime.OS.current_time() end
    })
    |> Map.put("iss", %Joken.Claim{
      generate: fn -> team_id end
    })
    |> Joken.generate_and_sign(%{}, signer)
  end

  @spec new_signer(String.t(), String.t(), String.t()) :: Joken.Signer.t()
  defp new_signer(alg, key_id, p8_file_path) do
    %Joken.Signer{
      alg: alg,
      jws: JOSE.JWS.from_map(%{"alg" => alg, "typ" => "JWT", "kid" => key_id}),
      jwk: JOSE.JWK.from_pem_file(p8_file_path)
    }
  end

  @spec schedule_message_after(non_neg_integer, :update_token) :: reference
  defp schedule_message_after(time, message) do
    _ =
      Logger.debug(fn ->
        "worker=apns_token_bearer, action=schedule, message=#{inspect(message)}, after=#{
          inspect(time)
        }"
      end)

    :erlang.send_after(time, self(), message)
  end
end
