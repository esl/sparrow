defmodule Sparrow.APNS.ResponseProcessingTest do
  use ExUnit.Case

  test "push response is handled correctly with single header" do
    headers = [{":status", "200"}]
    body = ""

    assert :ok == Sparrow.APNS.process_response({:ok, {headers, body}})
  end

  test "push response is handled correctly with single multiple headers, status first" do
    headers = [{":status", "200"}, {"some header", "200"}, {"another header", "value"}]
    body = ""

    assert :ok == Sparrow.APNS.process_response({:ok, {headers, body}})
  end

  test "push response is handled correctly with single header, status not first" do
    headers = [{"some header", "200"}, {"another header", "value"}, {":status", "200"}]
    body = ""

    assert :ok == Sparrow.APNS.process_response({:ok, {headers, body}})
  end

  test "push response is handled correctly with single header, no status header" do
    headers = [{"some header", "200"}, {"another header", "value"}]
    body = "{\"reason\" : \"MyReason\"}"
    assert {:error, {nil, "MyReason"}} == Sparrow.APNS.process_response({:ok, {headers, body}})
  end
end
