defmodule Sparrow.APNS.TokenBearer do
  @moduledoc """
  Module providing APNS token.
  """

  use GenServer
  require Logger

  @type bearer_token :: Joken.bearer_token()
  @type claims :: Joken.claims()

  @tab_name :sparrow_apns_tokens_bearer
  @apns_jwt_alg "ES256"
  @refresh_token_time :timer.minutes(50)

  @doc """
  Returns APNS token for token based authentication.
  """
  @spec get_token(atom) :: String.t() | nil
  def get_token(token_id) do
    @tab_name
    |> :ets.lookup(token_id)
    |> (fn [{_, token}] -> token end).()
  end

  @spec start_link(
          %{required(atom) => Sparrow.APNS.Token.t()}
          | {%{required(atom) => Sparrow.APNS.Token.t()}, pos_integer}
        ) :: GenServer.on_start()
  def start_link(tokens) do
    GenServer.start_link(__MODULE__, tokens, name: __MODULE__)
  end

  @spec init(
          %{required(atom) => Sparrow.APNS.Token.t()}
          | {%{required(atom) => Sparrow.APNS.Token.t()}, pos_integer}
        ) :: {:ok, Sparrow.APNS.TokenBearer.State.t()}

  def init({tokens, refresh_token_time}) do
    state = Sparrow.APNS.TokenBearer.State.new(tokens, refresh_token_time)
    @tab_name = :ets.new(@tab_name, [:set, :protected, :named_table])
    update_tokens(state)

    _ =
      Logger.info(fn ->
        "worker=apns_tokens_bearer, action=init, result=success"
      end)

    {:ok, state}
  end

  def init(tokens) do
    state = Sparrow.APNS.TokenBearer.State.new(tokens, @refresh_token_time)
    @tab_name = :ets.new(@tab_name, [:set, :protected, :named_table])
    update_tokens(state)

    _ =
      Logger.info(fn ->
        "worker=apns_tokens_bearer, action=init, result=success"
      end)

    {:ok, state}
  end

  @spec terminate(any, Sparrow.APNS.TokenBearer.State.t()) :: :ok
  def terminate(reason, _state) do
    ets_del = :ets.delete(@tab_name)

    _ =
      Logger.info(fn ->
        "worker=apns_tokens_bearer, action=terminate, reason=#{inspect(reason)}, ets_delate_result=#{
          inspect(ets_del)
        }"
      end)
  end

  @spec handle_info(:update_tokens | any, Sparrow.APNS.TokenBearer.State.t()) ::
          {:noreply, Sparrow.APNS.TokenBearer.State.t()}
  def handle_info(:update_tokens, state) do
    update_tokens(state)
    _ = Logger.debug(fn -> "worker=apns_tokens_bearer, action=token_update" end)
    {:noreply, state}
  end

  def handle_info(unknown, state) do
    _ =
      Logger.warn(fn ->
        "worker=apns_tokens_bearer, Unknown info #{inspect(unknown)}"
      end)

    {:noreply, state}
  end

  @spec update_tokens(Sparrow.APNS.TokenBearer.State.t()) :: :ok
  defp update_tokens(state) do
    schedule_message_after(state.update_token_after, :update_tokens)
    set_new_tokens(state)
  end

  @spec set_new_tokens(Sparrow.APNS.TokenBearer.State.t()) :: :ok
  defp set_new_tokens(state) do
    state.tokens
    |> Map.keys()
    |> Enum.each(fn key ->
      token_struct = Map.get(state.tokens, key)

      {:ok, token, _} =
        new_jwt_token(
          token_struct.key_id,
          token_struct.team_id,
          token_struct.p8_file_path
        )

      :ets.insert(@tab_name, {key, token})
    end)
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

  @spec schedule_message_after(pos_integer, :update_tokens) :: reference
  defp schedule_message_after(time, message) do
    _ =
      Logger.debug(fn ->
        "worker=apns_tokens_bearer, action=schedule, message=#{inspect(message)}, after=#{
          inspect(time)
        }"
      end)

    :erlang.send_after(time, self(), message)
  end
end
