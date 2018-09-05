defmodule Sparrow.APNS.TokenBearerTest do
  use ExUnit.Case

  alias Sparrow.FCM.V1.TokenBearer

  @google_json_path "./sparrow_token.json"

  test "token bearer ignores all messages" do
    {:ok, pid} = GenServer.start_link(TokenBearer, @google_json_path)

    for message <- [1, :a, "txt", pid] do
      send(pid, message)
    end

    :timer.sleep(100)
    {_, actual_queue_len} = :erlang.process_info(pid, :message_queue_len)
    assert 0 == actual_queue_len
  end
end
