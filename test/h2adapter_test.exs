defmodule ChatterboxAdapterTest do
  use ExUnit.Case
  use Quixir
  import Mock
  doctest Sparrow.ChatterboxAdapter

  @repeats 10

  test "open connection" do
    with_mock :h2_client, start_link: fn _, _, _, _ -> {:ok, self()} end do
      assert {:ok, self()} === Sparrow.ChatterboxAdapter.open("my.uri.at.domain", 1234, [])
      assert called :h2_client.start_link(:https, 'my.uri.at.domain', 1234, [])
    end
  end

  test "open connection different uri adreses and ports and extra options succesfully" do
    with_mock :h2_client, start_link: fn _, _, _, _ -> {:ok, self()} end do
      ptest [
              uri: string(min: 5, max: 20, chars: ?a..?z),
              port: int(min: 0, max: 65535),
              options: list(of: atom(), min: 2, max: 10)
            ],
            repeat_for: @repeats do
        assert {:ok, self()} === Sparrow.ChatterboxAdapter.open(uri, port, options)
        assert called :h2_client.start_link(:https, to_charlist(uri), port, options)
      end
    end
  end

  test "open connection different uri adreses and ports and extra option returning ignore" do
    with_mock :h2_client, start_link: fn _, _, _, _ -> :ignore end do
      ptest [
              uri: string(min: 5, max: 20, chars: ?a..?z),
              port: int(min: 0, max: 65535),
              options: list(of: atom(), min: 2, max: 10)
            ],
            repeat_for: @repeats do
        assert {:error, :ignore} === Sparrow.ChatterboxAdapter.open(uri, port, options)
        assert called :h2_client.start_link(:https, to_charlist(uri), port, options)
      end
    end
  end

  test "open connection different uri adreses and ports and extra option returning error with reason" do
    ptest [
            uri: string(min: 5, max: 20, chars: ?a..?z),
            reason: string(min: 5, max: 20, chars: ?a..?z),
            port: int(min: 0, max: 65535),
            options: list(of: atom(), min: 2, max: 10)
          ],
          repeat_for: @repeats do
      with_mock :h2_client, start_link: fn _, _, _, _ -> {:error, reason} end do
        assert {:error, reason} === Sparrow.ChatterboxAdapter.open(uri, port, options)
        assert called :h2_client.start_link(:https, to_charlist(uri), port, options)
      end
    end
  end

  test "close connection" do
    with_mock :h2_client, stop: fn _ -> :ok end do
      assert :ok === Sparrow.ChatterboxAdapter.close(self())
      assert called :h2_client.stop(self())
    end
  end

  test "sending post request returning error" do
    ptest [
            uri: string(min: 5, max: 20, chars: ?a..?z),
            path: string(min: 3, max: 15, chars: :ascii),
            headers: list(of: string(), min: 2, max: 20, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      with_mock :h2_connection, new_stream: fn _ -> {:error, 1234} end do
        conn = self()

        assert {:error, :unable_to_add_stream} ===
                 Sparrow.ChatterboxAdapter.post(conn, uri, path, headers, body)

        assert called :h2_connection.new_stream(conn)
      end
    end
  end

  def pid(string) when is_binary(string) do
    :erlang.list_to_pid('<#{string}>')
  end

  test "sending post request returning stream_id" do
    ptest [
            headers: list(of: string(), min: 2, max: 20, chars: :ascii),
            uri: string(min: 5, max: 20, chars: ?a..?z),
            path: string(min: 3, max: 15, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii)
          ],
          repeat_for: @repeats do
      stream_id = pid("0.4.5")
      conn = pid("0.2.3")

      with_mock :h2_connection,
        new_stream: fn _ -> stream_id end,
        send_headers: fn _, _, _ -> :ok end,
        send_body: fn _, _, _ -> :ok end do
        assert {:ok, stream_id} === Sparrow.ChatterboxAdapter.post(conn, uri, path, headers, body)

        args =
          :meck.history(:h2_connection)
          |> Enum.find(fn
            {_, {:h2_connection, :send_headers, _}, _} -> true
            _ -> false
          end)
          |> (fn {_, {_, _, [_, _, args]}, _} -> args end).()

        assert not Enum.empty?(args)
        assert {":scheme", "https"} in args
        assert {":authority", uri} in args
        assert {":path", path} in args
        assert {":method", "POST"} in args
        assert {"content-length", "#{byte_size(body)}"} in args
        assert Enum.all?(headers, fn elem -> elem in args end)
        assert called :h2_connection.send_body(conn, stream_id, body)
      end
    end
  end

  test "receive returning not empty body" do
    stream_id = pid("0.4.5")
    conn = pid("0.2.3")

    ptest [
            headers: list(of: string(), min: 2, max: 20, chars: :ascii),
            body: list(of: string(), min: 2, max: 20)
          ],
          repeat_for: @repeats do
      with_mock :h2_connection,
        get_response: fn _, _ -> {:ok, {headers, body}} end do
        assert {:ok, {headers, Enum.join(body)}} ===
                 Sparrow.ChatterboxAdapter.receive(conn, stream_id)

        assert called :h2_connection.get_response(conn, stream_id)
      end
    end
  end

  test "receive returning error" do
    stream_id = pid("0.4.5")
    conn = pid("0.2.3")

    with_mock :h2_connection,
      get_response: fn _, _ -> :not_ready end do
      assert {:error, :not_ready} === Sparrow.ChatterboxAdapter.receive(conn, stream_id)
      assert called :h2_connection.get_response(conn, stream_id)
    end
  end

  test "ping" do
    conn = pid("0.2.3")

    with_mock :h2_client,
      send_ping: fn _ -> :ok end do
      assert :ok === Sparrow.ChatterboxAdapter.ping(conn)
      assert called :h2_client.send_ping(conn)
    end
  end
end
