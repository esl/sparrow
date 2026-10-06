defmodule H2ClientAdapter.FinchTest do
  use ExUnit.Case

  alias Sparrow.H2ClientAdapter.Finch, as: H2Adapter

  @conn %{pool: nil, pid: nil, base_url: "https://localhost:443"}

  setup do
    {:ok, ref: {Finch.HTTP2.Pool, {self(), make_ref()}}}
  end

  test "response parts are translated", %{ref: ref} do
    assert {:response_part, ref, {:status, 200}} ==
             H2Adapter.handle_message({ref, {:status, 200}}, @conn)

    assert {:response_part, ref, {:headers, [{"apns-id", "1"}]}} ==
             H2Adapter.handle_message(
               {ref, {:headers, [{"apns-id", "1"}]}},
               @conn
             )

    assert {:response_part, ref, {:data, "body"}} ==
             H2Adapter.handle_message({ref, {:data, "body"}}, @conn)
  end

  test "end of response is translated", %{ref: ref} do
    assert {:done, ref} == H2Adapter.handle_message({ref, :done}, @conn)
  end

  test "error is translated to its reason", %{ref: ref} do
    error = %Finch.Error{reason: :connection_closed}

    assert {:error, ref, :connection_closed} ==
             H2Adapter.handle_message({ref, {:error, error}}, @conn)
  end

  test "messages not sent by finch are unknown" do
    assert :unknown == H2Adapter.handle_message({:ping, make_ref()}, @conn)
    assert :unknown == H2Adapter.handle_message({:END_STREAM, 1}, @conn)
    assert :unknown == H2Adapter.handle_message("message", @conn)
  end

  test "there is no response to read" do
    assert {:error, :not_ready} == H2Adapter.get_response(@conn, make_ref())
  end
end
