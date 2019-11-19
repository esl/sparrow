defmodule H2Integration.CerificateRejectedTest do
  alias Helpers.SetupHelper, as: Tools
  use ExUnit.Case

  alias Helpers.SetupHelper, as: Setup

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

    worker_pid = start_supervised!(Tools.h2_worker_spec(config))
    ref = Process.monitor(worker_pid)

    assert_receive {:DOWN, ^ref, :process, worker_pid, reason}

    case reason do
      {:tls_alert, 'bad certificate'} -> :ok
      {:tls_alert, {:bad_certificate, _}} -> :ok
      _ -> flunk(reason)
    end

  end
end
