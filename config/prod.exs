import Config

config :sparrow,
  fcm: [
    # Authentication
    path_to_json: "priv/fcm/token/sparrow_token.json",
    # H2Worker config
    endpoint: "fcm.googleapis.com",
    port: 443,
    tls_opts: [],
    ping_interval: 5000,
    reconnect_attempts: 3,
    # pool config
    tags: [],
    worker_num: 3,
    raw_opts: []
  ],
  apns: [
    dev: [
      [
        # Token based authentication
        auth_type: :token_based,
        token_id: :some_atom_id,
        # H2Worker config
        endpoint: "api.development.push.apple.com",
        port: 443,
        tls_opts: [],
        ping_interval: 5000,
        reconnect_attempts: 3,
        # pool config
        tags: [:first_batch_clients, :beta_users],
        worker_num: 3,
        raw_opts: []
      ],
      [
        # Certificate based uthentication
        auth_type: :certificate_based,
        cert: "priv/apns/dev_cert.pem",
        key: "priv/apns/dev_key.pem",
        # H2Worker config
        endpoint: "api.push.apple.com",
        port: 443,
        tls_opts: [],
        ping_interval: 5000,
        reconnect_attempts: 3,
        # pool config
        tags: [:another_batch_clients],
        worker_num: 3,
        raw_opts: []
      ]
    ],
    prod: [
      [
        # Authentication
        auth_type: :token_based,
        token_id: :some_other_id,
        # H2Worker config
        endpoint: "api.push.apple.com",
        port: 443,
        tls_opts: [],
        ping_interval: 5000,
        reconnect_attempts: 3,
        # pool config
        tags: [:test_prod, :alpha],
        worker_num: 3,
        raw_opts: []
      ]
    ],
    tokens: [
      [
        # TODO replace me with real data
        token_id: :some_atom_id,
        key_id: "FAKE_KEY_ID",
        team_id: "FAKE_TEAM_ID",
        p8_file_path: "token.p8"
      ],
      [
        # TODO replace me with real data
        token_id: :some_other_id,
        key_id: "FAKE_KEY_ID",
        team_id: "FAKE_TEAM_ID",
        p8_file_path: "token.p8"
      ]
    ]
  ]
