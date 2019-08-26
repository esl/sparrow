defmodule SparrowTest do
  use ExUnit.Case, async: false

  import Mock

  alias Helpers.SetupHelper, as: Setup

  @path "/3/device/"
  @cert_path "priv/ssl/client_cert.pem"
  @key_path "priv/ssl/client_key.pem"
  @project_id "sparrow-test-id"

  setup do
    {:ok, cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/v1/projects/#{@project_id}/messages:send",
            Helpers.CowboyHandlers.OkFCMHandler, []},
           {@path <> "OkResponseHandler",
            Helpers.CowboyHandlers.OkResponseHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    on_exit(fn ->
      Application.stop(:sparrow)
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, _pid} = start_supervised(Sparrow.PoolsWarden)

    {:ok, port: :ranch.get_port(cowboys_name), cowboy_pid: cowboy_pid}
  end

  test "Sparrow starts correctly", context do
    # DON'T COPY THIS TOKEN GETTER
    with_mock Sparrow.FCM.V1, [:passthrough],
      get_token_based_authentication: fn ->
        getter = fn ->
          {"authorization", "bearer dummy_token"}
        end

        Sparrow.H2Worker.Authentication.TokenBased.new(getter)
      end do
      fcm = [
        [
          path_to_json: "sparrow_token.json",
          endpoint: "localhost",
          port: context[:port],
          tags: [:yippee_ki_yay],
          worker_num: 3
        ]
      ]

      apns = [
        dev: [
          [
            auth_type: :certificate_based,
            cert: @cert_path,
            key: @key_path,
            endpoint: "localhost",
            port: context[:port],
            worker_num: 2,
            tags: [:wololo]
          ],
          [
            auth_type: :certificate_based,
            cert: @cert_path,
            key: @key_path,
            endpoint: "localhost",
            port: context[:port],
            worker_num: 2,
            tags: [:walala]
          ]
        ],
        prod: [
          [
            auth_type: :token_based,
            token_id: :some_atom_id,
            endpoint: "localhost",
            port: context[:port],
            worker_num: 4
          ]
        ],
        tokens: [
          [
            token_id: :some_atom_id,
            key_id: "FAKE_KEY_ID",
            team_id: "FAKE_TEAM_ID",
            p8_file_path: "token.p8"
          ]
        ]
      ]

      Application.stop(:sparrow)
      Application.put_env(:sparrow, :apns, nil)
      Application.put_env(:sparrow, :fcm, nil)

      Application.put_env(:sparrow, :fcm, fcm)
      Application.put_env(:sparrow, :apns, apns)

      Application.start(:sparrow)

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:dev)
               |> Sparrow.APNS.Notification.add_body("dummy body")
               |> Sparrow.API.push()

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:dev)
               |> Sparrow.APNS.Notification.add_body("dummy body")
               |> Sparrow.API.push([:wololo])

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:prod)
               |> Sparrow.APNS.Notification.add_title("dummy title")
               |> Sparrow.API.push()

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:prod)
               |> Sparrow.APNS.Notification.add_title("dummy title")
               |> Sparrow.API.push([], is_sync: false)

      assert {:error, :configuration_error} ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:dev)
               |> Sparrow.APNS.Notification.add_body("dummy body")
               |> Sparrow.API.push([:welele])

      android =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("dummy title")

      notification =
        Sparrow.FCM.V1.Notification.new(:topic, "news")
        |> Sparrow.FCM.V1.Notification.add_android(android)

      assert :ok == Sparrow.API.push(notification)
      assert :ok == Sparrow.API.push(notification, [:yippee_ki_yay])

      assert {:error, :configuration_error} ==
               Sparrow.API.push(notification, [
                 :yippee_ki_yay,
                 :wrong_tag
               ])
    end
  end

  test "Sparrow starts correctly, FCM only", context do
    # DON'T COPY THIS TOKEN GETTER
    with_mock Sparrow.FCM.V1, [:passthrough],
      get_token_based_authentication: fn ->
        getter = fn ->
          {"authorization", "bearer dummy_token"}
        end

        Sparrow.H2Worker.Authentication.TokenBased.new(getter)
      end do
      fcm = [
        [
          path_to_json: "sparrow_token.json",
          endpoint: "localhost",
          port: context[:port],
          tags: [:yippee_ki_yay],
          worker_num: 3
        ]
      ]

      Application.stop(:sparrow)
      Application.put_env(:sparrow, :apns, nil)
      Application.put_env(:sparrow, :fcm, nil)

      Application.put_env(:sparrow, :fcm, fcm)
      Application.start(:sparrow)

      android =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("dummy title")

      notiifcation =
        Sparrow.FCM.V1.Notification.new(:topic, "news")
        |> Sparrow.FCM.V1.Notification.add_android(android)

      assert :ok == Sparrow.API.push(notiifcation)
      assert :ok == Sparrow.API.push(notiifcation, [:yippee_ki_yay])
      assert :ok == Sparrow.API.push(notiifcation, [], is_sync: false)

      assert {:error, :configuration_error} ==
               Sparrow.API.push(notiifcation, [
                 :yippee_ki_yay,
                 :wrong_tag
               ])
    end
  end

  test "Sparrow starts correctly, APNS only", context do
    apns = [
      dev: [
        [
          auth_type: :certificate_based,
          cert: @cert_path,
          key: @key_path,
          endpoint: "localhost",
          port: context[:port],
          worker_num: 2,
          tags: [:wololo]
        ],
        [
          auth_type: :certificate_based,
          cert: @cert_path,
          key: @key_path,
          endpoint: "localhost",
          port: context[:port],
          worker_num: 2,
          tags: [:walala]
        ]
      ],
      prod: [
        [
          auth_type: :token_based,
          token_id: :some_atom_id,
          endpoint: "localhost",
          port: context[:port],
          worker_num: 4
        ]
      ],
      tokens: [
        [
          token_id: :some_atom_id,
          key_id: "FAKE_KEY_ID",
          team_id: "FAKE_TEAM_ID",
          p8_file_path: "token.p8"
        ]
      ]
    ]

    Application.stop(:sparrow)

    Application.put_env(:sparrow, :apns, nil)
    Application.put_env(:sparrow, :fcm, nil)

    Application.put_env(:sparrow, :apns, apns)
    Application.start(:sparrow)

    assert :ok ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:dev)
             |> Sparrow.APNS.Notification.add_body("dummy body")
             |> Sparrow.API.push()

    assert :ok ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:dev)
             |> Sparrow.APNS.Notification.add_body("dummy body")
             |> Sparrow.API.push([:wololo])

    assert :ok ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:prod)
             |> Sparrow.APNS.Notification.add_title("dummy title")
             |> Sparrow.API.push()

    assert {:error, :configuration_error} ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:dev)
             |> Sparrow.APNS.Notification.add_body("dummy body")
             |> Sparrow.API.push([:welele])
  end
end
