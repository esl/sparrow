defmodule Sparrow.APNS.TokenBearerTest do
  use ExUnit.Case

  @key_id "KEYID"
  @team_id "TEAMID"
  @p8_file_path "token.p8"
  @refresh_time 100
  @token_id :token_id
  setup do
    config = %{
      @token_id =>
        Sparrow.APNS.Token.new(
          @key_id,
          @team_id,
          @p8_file_path
        )
    }

    state = %Sparrow.APNS.TokenBearer.State{
      tokens: %{
        @token_id =>
          Sparrow.APNS.Token.new(
            @key_id,
            @team_id,
            @p8_file_path
          )
      },
      update_token_after: @refresh_time
    }

    {:ok, pid} =
      GenServer.start_link(Sparrow.APNS.TokenBearer, {config, @refresh_time})

    {:ok, config: config, token_bearer_pid: pid, state: state}
  end

  test "token gets refresh time correctly", context do
    refresh_time =
      context[:token_bearer_pid]
      |> :sys.get_state()
      |> Map.get(:update_token_after)

    assert refresh_time == @refresh_time
  end

  test "token gets updated" do
    token_before_update = Sparrow.APNS.TokenBearer.get_token(@token_id)
    :timer.sleep(200)
    token_after_update = Sparrow.APNS.TokenBearer.get_token(@token_id)

    assert token_before_update != token_after_update
  end

  test "token bearer is initialized correctly", context do
    assert context[:state] == :sys.get_state(context[:token_bearer_pid])
  end

  test "token bearer ignores unknown messages", context do
    before_unexpected_message_state = :sys.get_state(context[:token_bearer_pid])
    send(context[:token_bearer_pid], :unknown)

    assert before_unexpected_message_state ==
             :sys.get_state(context[:token_bearer_pid])
  end

  test "terminate deletes ets table", context do
    Process.unlink(context[:token_bearer_pid])
    Process.exit(context[:token_bearer_pid], :kill)
    wait_for_proccess_to_die(context[:token_bearer_pid])
    assert :undefined == :ets.info(:sparrow_apns_token_bearer)
  end

  test "init, terminate deletes ets table", context do
    Process.unlink(context[:token_bearer_pid])
    Process.exit(context[:token_bearer_pid], :kill)
    wait_for_proccess_to_die(context[:token_bearer_pid])
    assert :undefined == :ets.info(:sparrow_apns_token_bearer)
    Sparrow.APNS.TokenBearer.init(context[:config])
    Sparrow.APNS.TokenBearer.terminate(:any, context[:state])

    assert :undefined == :ets.info(:sparrow_apns_token_bearer)
  end

  defp wait_for_proccess_to_die(pid) do
    case Process.alive?(pid) do
      true ->
        :timer.sleep(10)
        wait_for_proccess_to_die(pid)

      _ ->
        :oik
    end
  end
end
