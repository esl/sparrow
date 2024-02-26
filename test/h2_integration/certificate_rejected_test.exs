defmodule H2Integration.CerificateRejectedTest do
  use ExUnit.Case

  import Mox
  setup :set_mox_global
  setup :verify_on_exit!

  alias Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  import Helpers.SetupHelper, only: [passthrough_h2: 1]
  setup :passthrough_h2

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
    config = Setup.create_h2_worker_config(Setup.server_host(), context[:port])

    headers = Setup.default_headers()
    body = "sound of silence, test body"

    request =
      OuterRequest.new(headers, body, "/RejectCertificateHandler", 3_000)

    worker_pid = start_supervised!(Setup.h2_worker_spec(config))

    assert {:error, reason} =
             GenServer.call(worker_pid, {:send_request, request})

    case reason do
      {:unable_to_connect, {:tls_alert, ~c"bad certificate"}} -> :ok
      {:unable_to_connect, {:tls_alert, {:bad_certificate, _}}} -> :ok
      :connection_lost -> :ok
      _ -> flunk("Wrong error code: #{inspect(reason)}")
    end
  end
end
