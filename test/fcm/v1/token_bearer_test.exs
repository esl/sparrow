defmodule Sparrow.FCM.V1.TokenBearerTest do
  use ExUnit.Case
  import Mock

  @google_json_path "./sparrow_token.json"

  @token "dummy token"
  @expires 1_234_567
  test "token bearer gets token" do
    with_mock Goth.Token,
      for_scope: fn {_, scope} ->
        {:ok,
         %Goth.Token{
           expires: @expires,
           scope: scope,
           sub: nil,
           token: @token,
           type: "Bearer"
         }}
      end do
      assert @token == Sparrow.FCM.V1.TokenBearer.get_token("")
    end
  end

  test "token bearer starts" do
    config = [[{:path_to_json, @google_json_path}]]
    {:ok, pid} = start_supervised(
      %{
      id: Sparrow.FCM.V1.TokenBearer,
      start: {Sparrow.FCM.V1.TokenBearer, :start_link, [config]}
    })

    assert is_pid(pid)
  end
end
