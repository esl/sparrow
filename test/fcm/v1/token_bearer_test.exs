defmodule Sparrow.FCM.V1.TokenBearerTest do
  use ExUnit.Case
  import Mock

  @google_json_path "./sparrow_token.json"

  @token "dummy token"
  @expires 1_234_567
  test "token bearer gets token" do
    with_mock Goth.Token,
      for_scope: fn scope ->
        {:ok, %Goth.Token{
          expires: @expires,
          scope: scope,
          sub: nil,
          token: @token,
          type: "Bearer"
        }}
      end do
      assert @token == Sparrow.FCM.V1.TokenBearer.get_token()
    end
  end
  test "" do
    {:ok, pid} = Sparrow.FCM.V1.TokenBearer.start_link(@google_json_path)
    assert is_pid(pid)
  end
end
