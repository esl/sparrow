use Mix.Config

config :sparrow,
  config: [
    fcm: [
      [
        # TODO replace me with real data
        path_to_json: "sparrow_token.json"
      ]
    ],
    apns: [
      dev: [
        [
          auth_type: :token_based,
          token_id: :some_atom_id
        ]
      ],
      prod: [
        [
          auth_type: :token_based,
          token_id: :some_atom_id
        ]
      ],
      tokens: [
        [
          # TODO replace me with real data
          token_id: :some_atom_id,
          key_id: "FAKE_KEY_ID",
          team_id: "FAKE_TEAM_ID",
          p8_file_path: "token.p8"
        ]
      ]
    ]
  ]
