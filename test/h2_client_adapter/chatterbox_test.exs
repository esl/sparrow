defmodule H2ClientAdapter.ChatterboxTest do
  use ExUnit.Case
  use Quixir
  use AssertEventually, timeout: 5000, interval: 10

  import Mock
  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter

  doctest H2Adapter

  @repeats 10

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

  test "open connection" do
    with_mock :h2_client, start: fn _, _, _, _ -> {:ok, self()} end do
      assert {:ok, self()} === H2Adapter.open("my.domain.at.domain", 1234, [])

      assert called :h2_client.start(
                      :https,
                      ~c"my.domain.at.domain",
                      1234,
                      []
                    )
    end
  end

  test "open connection different domain adreses and ports and extra options succesfully" do
    with_mock :h2_client, start: fn _, _, _, _ -> {:ok, self()} end do
      ptest [
              domain: string(min: 5, max: 20, chars: ?a..?z),
              port: int(min: 0, max: 65_535),
              options: list(of: atom(), min: 2, max: 10)
            ],
            repeat_for: @repeats do
        assert {:ok, self()} === H2Adapter.open(domain, port, options)

        assert called :h2_client.start(
                        :https,
                        to_charlist(domain),
                        port,
                        options
                      )
      end
    end
  end

  test "open connection different domain adreses and ports and extra option returning ignore" do
    with_mock :h2_client, start: fn _, _, _, _ -> :ignore end do
      ptest [
              domain: string(min: 5, max: 20, chars: ?a..?z),
              port: int(min: 0, max: 65_535),
              options: list(of: atom(), min: 2, max: 10)
            ],
            repeat_for: @repeats do
        assert {:error, :ignore} === H2Adapter.open(domain, port, options)

        assert called :h2_client.start(
                        :https,
                        to_charlist(domain),
                        port,
                        options
                      )
      end
    end
  end

  test "open connection different domain adreses and ports and extra option returning error with reason" do
    ptest [
            domain: string(min: 5, max: 20, chars: ?a..?z),
            reason: string(min: 5, max: 20, chars: ?a..?z),
            port: int(min: 0, max: 65_535),
            options: list(of: atom(), min: 2, max: 10)
          ],
          repeat_for: @repeats do
      with_mock :h2_client, start: fn _, _, _, _ -> {:error, reason} end do
        assert {:error, reason} === H2Adapter.open(domain, port, options)

        assert called :h2_client.start(
                        :https,
                        to_charlist(domain),
                        port,
                        options
                      )
      end
    end
  end

  test "close connection" do
    with_mock :h2_client, stop: fn _ -> :ok end do
      assert :ok === H2Adapter.close(self())
      assert called :h2_client.stop(self())
    end
  end

  test "sending post request returning error" do
    ptest [
            reason: string(min: 5, max: 20, chars: ?a..?z),
            domain: string(min: 5, max: 20, chars: ?a..?z),
            path: string(min: 3, max: 15, chars: :ascii),
            headersA1: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB1: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      with_mock :h2_connection, new_stream: fn _ -> {:error, reason} end do
        conn = self()
        headers = List.zip([headersA1, headersB1])

        assert {:error, reason} ===
                 H2Adapter.post(conn, domain, path, headers, body)

        assert called :h2_connection.new_stream(conn)
      end
    end
  end

  test "sending post request returning stream_id" do
    ptest [
            headersA1: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB1: list(of: string(), min: 2, max: 2, chars: :ascii),
            domain: string(min: 5, max: 20, chars: ?a..?z),
            path: string(min: 3, max: 15, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 0, max: 65_535)
          ],
          repeat_for: @repeats do
      conn = pid("0.2.3")
      headers = List.zip([headersA1, headersB1])

      with_mock :h2_connection,
        new_stream: fn _ -> stream_id end,
        send_headers: fn _, _, _ -> :ok end,
        send_body: fn _, _, _ -> :ok end do
        assert {:ok, stream_id} ===
                 H2Adapter.post(conn, domain, path, headers, body)

        args =
          :h2_connection
          |> :meck.history()
          |> Enum.find(fn
            {_, {:h2_connection, :send_headers, _}, _} -> true
            _ -> false
          end)
          |> (fn {_, {_, _, [_, _, args]}, _} -> args end).()

        assert not Enum.empty?(args)
        assert {":scheme", "https"} in args
        assert {":authority", domain} in args
        assert {":path", path} in args
        assert {":method", "POST"} in args
        assert {"content-length", "#{byte_size(body)}"} in args
        assert Enum.all?(headers, fn elem -> elem in args end)
        assert called :h2_connection.send_body(conn, stream_id, body)
      end
    end
  end

  test " succesfully getting response from get_response" do
    ptest [
            headers: list(of: string(), min: 2, max: 20, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 0, max: 65_535)
          ],
          repeat_for: @repeats do
      conn = pid("0.2.3")

      with_mock :h2_connection,
        get_response: fn _, _ -> {:ok, {headers, body}} end do
        assert {:ok, {headers, body}} == H2Adapter.get_response(conn, stream_id)

        assert called :h2_connection.get_response(conn, stream_id)
      end
    end
  end

  test "get_response timeouting" do
    ptest [
            stream_id: int(min: 0, max: 65_535)
          ],
          repeat_for: @repeats do
      conn = pid("0.2.3")

      with_mock :h2_connection,
        get_response: fn _, _ -> :not_ready end do
        assert {:error, :not_ready} == H2Adapter.get_response(conn, stream_id)

        assert called :h2_connection.get_response(conn, stream_id)
      end
    end
  end

  test "ping" do
    conn = pid("0.2.3")

    with_mock :h2_client,
      send_ping: fn _ -> :ok end do
      assert :ok === H2Adapter.ping(conn)
      assert called :h2_client.send_ping(conn)
    end
  end

  defp pid(string) when is_binary(string) do
    :erlang.list_to_pid(~c"<#{string}>")
  end
end
