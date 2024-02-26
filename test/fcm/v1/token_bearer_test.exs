defmodule Sparrow.FCM.V1.TokenBearerTest do
  use ExUnit.Case

  import Mock
  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  @google_json_path "./sparrow_token.json"

  @token "dummy token"
  @expires 1_234_567

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  test "token bearer gets token" do
    with_mock Goth,
      fetch: fn _name ->
        {:ok,
         %Goth.Token{
           expires: @expires,
           scope: "https://www.googleapis.com/auth/firebase.messaging",
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

    {:ok, pid} =
      start_supervised(%{
        id: Sparrow.FCM.V1.TokenBearer,
        start: {Sparrow.FCM.V1.TokenBearer, :start_link, [config]}
      })

    assert is_pid(pid)
  end
end
