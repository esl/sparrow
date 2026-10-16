defmodule Sparrow.RequestTest do
  use ExUnit.Case
  use Quixir

  @repeats 10

  test "creating input request works" do
    ptest [
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      headers = Enum.zip([headersA, headersB])

      %name{} = Sparrow.Request.new(headers, body, path)
      assert Sparrow.Request == name
    end
  end
end
