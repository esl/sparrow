defmodule Sparrow.APNS.TokenBearerTest do
  use ExUnit.Case

  @key_id "KEYID"
  @team_id "TEAMID"
  @p8_file_path "token.p8"
  @refresh_token_time 100
  setup do
    config =
      Sparrow.APNS.Token.new(
        @key_id,
        @team_id,
        @p8_file_path,
        @refresh_token_time
      )

    state = %Sparrow.APNS.TokenBearer.State{
      key_id: @key_id,
      team_id: @team_id,
      p8_file_path: @p8_file_path,
      refresh_token_time: @refresh_token_time
    }

    {:ok, pid} = GenServer.start_link(Sparrow.APNS.TokenBearer, config)
    {:ok, config: config, token_bearer_pid: pid, state: state}
  end

  test "token gets updated", context do
    token_before_update = Sparrow.APNS.TokenBearer.get_token()
    :timer.sleep(150)
    token_after_update = Sparrow.APNS.TokenBearer.get_token()

    assert token_before_update != token_after_update
  end

  test "token bearer is initialized correctly", context do
    assert context[:state] == :sys.get_state(context[:token_bearer_pid])
  end

  test "token bearer ignores unknown messages", context do
    before_unexpected_message_state = :sys.get_state(context[:token_bearer_pid])
    send(context[:token_bearer_pid], :unknown)
    assert before_unexpected_message_state == :sys.get_state(context[:token_bearer_pid])
  end

  test "terminate deletes ets table", context do
    Process.unlink(context[:token_bearer_pid])
    Process.exit(context[:token_bearer_pid], :kill)
    wait_for_proccess_to_die(context[:token_bearer_pid])
    assert :undefined == :ets.info(:sparrow_apns_token_bearer)
  end

  test "inint, terminate deletes ets table", context do
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
