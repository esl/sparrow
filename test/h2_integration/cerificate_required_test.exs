defmodule H2Integration.CerificateRequiredTest do
  use ExUnit.Case
  alias H2Integration.Helpers.SetupHelper, as: Setup
  alias Sparrow.H2Worker.Request, as: OuterRequest

  @port 8090

  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      :cowboy_router.compile([
        {":_",
         [
           {"/EchoClientCerificateHandler",
            H2Integration.Helpers.CowboyHandlers.EchoClientCerificateHandler, []}
         ]}
      ])
      |> Setup.start_cowboy_tls(:positive_cerificate_verification, @port)

    on_exit(fn ->
      :cowboy.stop_listener(cowboys_name)
    end)

    :ok
  end

  test "cowboy replies with sent cerificate" do
    config =
      Setup.create_h2_worker_config(Setup.server_host(), @port, [
        {:certfile, System.cwd() <> "/priv/ssl/client_cert.pem"},
        {:keyfile, System.cwd() <> "/priv/ssl/client_key.pem"}
      ])

    headers = Setup.default_headers()
    body = "body"
    worker_spec = Setup.child_spec(args: config)
    request = OuterRequest.new(headers, body, "/EchoClientCerificateHandler", 2_000)

    {:ok, worker_pid} = start_supervised(worker_spec, [])
    {:ok, {answer_headers, answer_body}} = GenServer.call(worker_pid, {:send_request, request})

    {:ok, pem_bin} = File.read(System.cwd() <> "/priv/ssl/client_cert.pem")

    expected_subject =
      H2Integration.Helpers.CerificateHelper.get_subject_name_form_not_encoded_cert(pem_bin)

    assert Enum.any?(answer_headers, &(&1 == {":status", "200"}))
    assert expected_subject == answer_body
  end

  test "worker rejects cowboy cerificate" do
    config =
      Sparrow.H2Worker.Config.new(
        Setup.server_host(),
        @port,
        [
          {:verify, :verify_peer},
          {:cacertfile, System.cwd() <> "/priv/ssl/client_cert.pem"}
        ],
        10_000
      )

    worker_spec = Setup.child_spec(args: config, name: :worker_name)
    {:error, reason} = start_supervised(worker_spec)
    {actual_reason, _} = reason
    assert {:tls_alert, 'bad certificate'} == actual_reason
  end
end
