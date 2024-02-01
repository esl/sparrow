defmodule H2Worker.RequestSetTest do
  use ExUnit.Case
  use Quixir

  alias Sparrow.H2Worker.RequestSet
  alias Sparrow.H2Worker.RequestState, as: InnerRequest
  doctest Sparrow.H2Worker.RequestSet

  @repeats 10

  test "collection is correctly initalizing" do
    requests = RequestSet.new()
    assert Enum.empty?(requests)
  end

  test "collection add, remove, get_addressee behavious correctly" do
    ptest [
            headersA1: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB1: list(of: string(), min: 2, max: 2, chars: :ascii),
            body1: string(min: 3, max: 15, chars: :ascii),
            path1: string(min: 3, max: 15, chars: :ascii),
            from_tag1: atom(min: 5, max: 20),
            headersA2: list(of: string(), min: 3, max: 3, chars: :ascii),
            headersB2: list(of: string(), min: 3, max: 3, chars: :ascii),
            body2: string(min: 3, max: 15, chars: :ascii),
            path2: string(min: 3, max: 15, chars: :ascii),
            from_tag2: atom(min: 5, max: 20)
          ],
          repeat_for: @repeats do
      stream_id1 = 1111
      stream_id2 = 2222
      stream_id3_not_exisiting = 3333

      headers1 = List.zip([headersA1, headersB1])
      from_pid1 = pid("0.12.13")
      headers2 = List.zip([headersA2, headersB2])
      from_pid2 = pid("0.13.12")

      outer_request1 = Sparrow.H2Worker.Request.new(headers1, body1, path1)
      outer_request2 = Sparrow.H2Worker.Request.new(headers2, body2, path2)

      request1 =
        InnerRequest.new(outer_request1, {from_pid1, from_tag1}, make_ref())

      request2 =
        InnerRequest.new(outer_request2, {from_pid2, from_tag2}, make_ref())

      requests_collection = RequestSet.new()
      assert Enum.empty?(requests_collection)

      updated_requests_collection =
        RequestSet.add(requests_collection, stream_id1, request1)

      assert 1 == Enum.count(updated_requests_collection)

      reupdated_requests_collection =
        RequestSet.add(updated_requests_collection, stream_id2, request2)

      assert 2 == Enum.count(reupdated_requests_collection)

      rereupdated_requests_collection =
        RequestSet.add(updated_requests_collection, stream_id2, request2)

      assert 2 == Enum.count(rereupdated_requests_collection)

      assert {:ok, request1} ==
               RequestSet.get_request(reupdated_requests_collection, stream_id1)

      assert {:error, :not_found} ==
               RequestSet.get_request(
                 reupdated_requests_collection,
                 stream_id3_not_exisiting
               )

      requests_collection_with_request2_removed =
        RequestSet.remove(reupdated_requests_collection, stream_id1)

      assert 1 == Enum.count(requests_collection_with_request2_removed)
      assert [stream_id2] == Map.keys(requests_collection_with_request2_removed)
    end
  end

  defp pid(string) when is_binary(string) do
    :erlang.list_to_pid(~c"<#{string}>")
  end
end
