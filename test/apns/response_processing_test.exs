defmodule Sparrow.APNS.ResponseProcessingTest do
  use ExUnit.Case

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  test "push response is handled correctly with single header" do
    headers = [{":status", "200"}]
    body = ""

    assert :ok == Sparrow.APNS.process_response({:ok, {headers, body}})
  end

  test "push response is handled correctly with single multiple headers, status first" do
    headers = [
      {":status", "200"},
      {"some header", "200"},
      {"another header", "value"}
    ]

    body = ""

    assert :ok == Sparrow.APNS.process_response({:ok, {headers, body}})
  end

  test "push response is handled correctly with single header, status not first" do
    headers = [
      {"some header", "200"},
      {"another header", "value"},
      {":status", "200"}
    ]

    body = ""

    assert :ok == Sparrow.APNS.process_response({:ok, {headers, body}})
  end

  test "push response is handled correctly with single header, no status header" do
    headers = [{"some header", "200"}, {"another header", "value"}]
    body = "{\"reason\" : \"MyReason\"}"

    assert {:error, :MyReason} ==
             Sparrow.APNS.process_response({:ok, {headers, body}})
  end
end
