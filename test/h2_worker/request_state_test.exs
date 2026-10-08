defmodule H2Worker.RequestStateTest do
  use ExUnit.Case

  alias Sparrow.H2Worker.Request
  alias Sparrow.H2Worker.RequestSet
  alias Sparrow.H2Worker.RequestState

  setup do
    request = Request.new([{"header", "value"}], "body", "/path")
    {:ok, request: RequestState.new(request, {self(), make_ref()}, make_ref())}
  end

  test "response is not ready before status is received", %{request: request} do
    assert {:error, :not_ready} == RequestState.response(request)
  end

  test "response is built out of collected parts", %{request: request} do
    request =
      request
      |> RequestState.add_response_part({:status, 200})
      |> RequestState.add_response_part({:headers, [{"apns-id", "1"}]})
      |> RequestState.add_response_part({:data, "bo"})
      |> RequestState.add_response_part({:data, "dy"})
      |> RequestState.add_response_part({:headers, [{"trailer", "2"}]})

    assert {:ok,
            {[{":status", "200"}, {"apns-id", "1"}, {"trailer", "2"}], "body"}} ==
             RequestState.response(request)
  end

  test "response without data has empty body", %{request: request} do
    request =
      request
      |> RequestState.add_response_part({:status, 200})
      |> RequestState.add_response_part({:headers, []})

    assert {:ok, {[{":status", "200"}], ""}} == RequestState.response(request)
  end

  test "request set adds part only to existing request", %{request: request} do
    requests = RequestSet.add(RequestSet.new(), :stream, request)

    assert requests ==
             RequestSet.add_response_part(requests, :other, {:status, 200})

    requests = RequestSet.add_response_part(requests, :stream, {:status, 200})
    {:ok, request} = RequestSet.get_request(requests, :stream)

    assert {:ok, {[{":status", "200"}], ""}} == RequestState.response(request)
  end

  test "request set pops existing request", %{request: request} do
    requests = RequestSet.add(RequestSet.new(), :stream, request)

    assert {nil, requests} == RequestSet.pop(requests, :other)
    assert {request, RequestSet.new()} == RequestSet.pop(requests, :stream)
  end
end
