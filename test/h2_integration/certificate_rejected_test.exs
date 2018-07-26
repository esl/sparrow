defmodule H2Integration.CerificateRejectedTest do
  use ExUnit.Case
  alias H2Integration.Helpers.SetupHelper, as: Setup

  @port 8081

  setup_all do
    {:ok, _cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {"/RejectCertificateHandler",
            H2Integration.Helpers.CowboyHandlers.RejectCertificateHandler, []}
         ]}
      ])
      |> Setup.start_cowboy_tls(:negative_cerificate_verification, @port)

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    :ok
  end

  test "cowboy does not accept certificate" do
    config =
      Setup.create_h2_worker_config(Setup.server_host(), @port, [
        {:certfile, System.cwd() <> "/priv/ssl/client_cert.pem"},
        {:keyfile, System.cwd() <> "/priv/ssl/client_key.pem"}
      ])

    worker_spec = Setup.child_spec(args: config)

    {:error, reason} = start_supervised(worker_spec, [])
    {actual_reason, _} = reason
    assert {:tls_alert, 'bad certificate'} == actual_reason
  end
end
