defmodule SparrowTest do
  use ExUnit.Case

  @apns_pool_raw_config [
    auth_type: :token_based,
    token_id: :some_atom_id,
    endpoint: "api.push.apple.com",
    port: 443,
    worker_num: 1
  ]
  @fcm_raw_config [
    path_to_json: "sparrow_token.json"
  ]

  @apns_raw_config [
    dev: [
      @apns_pool_raw_config,
      [{:pool_name, :custom_pool_name} | @apns_pool_raw_config],
      [{:pool_name, :another_custom_pool_name} | @apns_pool_raw_config]
    ],
    prod: [
      @apns_pool_raw_config,
      @apns_pool_raw_config
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

  test "APNS supervision tree starts" do
    {:ok, pid} = Sparrow.APNSSupervisor.start_link(@apns_raw_config)
    assert 6 == Map.get(Supervisor.count_children(pid), :workers)
  end

  test "FCM supervision tree starts" do
    {:ok, pid} = Sparrow.FCMSupervisor.start_link(@fcm_raw_config)
    assert 2 == Map.get(Supervisor.count_children(pid), :workers)
  end

end
