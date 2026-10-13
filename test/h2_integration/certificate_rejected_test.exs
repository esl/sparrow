defmodule H2Integration.CerificateRejectedTest do
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.Request, as: OuterRequest

  setup_all do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/RejectCertificateHandler",
            Helpers.CowboyHandlers.RejectCertificateHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(
        certificate_required: :negative_cerificate_verification
      )

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  test "cowboy does not accept certificate", context do
    config = Setup.create_pool_config(Setup.server_host(), context[:port])

    headers = Setup.default_headers()
    body = "sound of silence, test body"

    request =
      OuterRequest.new(headers, body, "/RejectCertificateHandler", 3_000)

    pool = Setup.start_pool_with_config(config)

    assert {:error, reason} = Sparrow.Pool.send_request(pool, request)

    case reason do
      # Server closes the connection after the handshake
      :connection_lost -> :ok
      {:unable_to_connect, _reason} -> :ok
      _ -> flunk("Wrong error code: #{inspect(reason)}")
    end
  end
end
