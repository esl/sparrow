# Sparrow
## Summary
Sparrow is an Elixir library for [push notifications](https://en.wikipedia.org/wiki/Push_technology#Push_notification).
[![Build Status](https://travis-ci.org/esl/sparrow.svg?branch=master)](https://travis-ci.org/esl/sparrow)
[![Coverage Status](https://coveralls.io/repos/github/esl/sparrow/badge.svg)](https://coveralls.io/github/esl/sparrow)

Currently it provides support for the following APIs:
* [FCM v1](https://firebase.google.com/docs/cloud-messaging/)
* [APNS](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/APNSOverview.html)

## Requirements
* Elixir 1.13 or higher
* Erlang OTP 24 or higher

# Build sparrow config
This section describes how to write a config file for Sparrow.
If you wish to use just one of the following services, do not include the other in the config.

```elixir
config :sparrow, 
    fcm: [...],
    apns: [...]
```

## Config examples

FCM only:

```elixir
config :sparrow, fcm: [
        [
            path_to_json: "path/to/google-services.json"
        ]
    ]
```

APNS only:

```elixir
config :sparrow, 
    apns: [
        dev:
        [
            [
                auth_type: :certificate_based,
                cert: "path/to/apns/cert.pem",
                key: "path/to/apns/key.pem"
            ]
        ],
        prod:
        [
            [ 
                auth_type: :token_based,
                token_id: :some_atom_id,
                tags: [:production, :token_based_auth]
            ],
            [ 
                auth_type: :token_based,
                token_id: :other_atom_id,
                tags: [:other_production_pool, :token_based_auth]
            ]
        ],
        tokens:
        [
            [
                token_id: :some_atom_id,
                key_id: "FAKE_KEY_ID",
                team_id: "FAKE_TEAM_ID",
                p8_file_path: "path/to/file/token.p8"
            ],
             [
                token_id: :other_atom_id,
                key_id: "OTHER_FAKE_KEY_ID",
                team_id: "OTHER_FAKE_TEAM_ID",
                p8_file_path: "path/to/file/other/token.p8"
            ]
        ]
    ]
```

Both FCM  and APNS:

```elixir
config :sparrow,
    fcm: [
        [
            path_to_json: "path/to/fcm_token.json"
        ]
    ],
    apns: [
        dev:
        [
            [
                auth_type: :certificate_based,
                cert: "path/to/apns/cert.pem",
                key: "path/to/apns/key.pem"
            ]
        ]
    ]
```

## Config options description

### FCM specific
- `:path_to_json` - is a path to a json file provided by FCM

### APNS specific
- `:auth_type` - defines the authentication type, the allowed values are: `:token_based`, `:certificate_based`

    - `:token_based` requires setting:
        - `:token_id` - is a unique atom referring to a token with the same `:token_id` in config
    
    - `:certificate_based` requires setting:
    
        - `:cert` - path to the certificate file provided by APNS
        - `:key` - path to the key file provided by APNS


### Connection config
- `:endpoint` - service uri
- `:port` - service port
- `:tls_opts` - passed to erlang [ssl](http://erlang.org/doc/man/ssl.html) module (see DATA TYPES -> ssl_option())
- `:ping_interval` - number of miliseconds between each [ping](https://http2.github.io/http2-spec/#PING), to switch ping off set `:ping_interval` to `nil`
- `:reconnect_attempts` - number of attempts to reconnect before failing the connection

### Connection pool config
- `:pool_name` - defines pool name, not recommended - please use [tags](#tags) instead 
- `:tags` - see the [tags](#tags) section
- `:worker_num` - number of workers in a pool
- `:raw_opts` - opts passed directly to [wpool](github.com/inaka/worker_pool)

### FCM config example
```elixir
fcm_config = 
    [
        [
            # Authentication
            path_to_json: "path/to/fcm_token.json", # mandatory, path to FCM authentication JSON file
            # Connection config
            endpoint: "fcm.googleapis.com", # optional
            port: 443, # optional
            tls_opts: [], # optional
            ping_interval: 5000, # optional
            reconnect_attempts: 3, # optional
            # Pool config 
            tags: [], # optional
            worker_num: 3, # optional
            raw_opts: [] # optional, options passed directly to wpool
        ]
    ]
```
### APNS config example
```elixir
apns_config = 
[
    dev: [apns_pool_1, apns_pool_2 ], # list of apns_pool_configs by default set to APNS development endpoint, is a list of APNS pools
    prod: [apns_pool_3 ],  # list of apns_pool_configs by default set to APNS production endpoint, is a list of APNS pools
    tokens: [apns_token_1, apns_token_2 ] # optional, is a list of APNS tokens
]
```
### APNS pool example

Token based authentication example:
```elixir
apns_pool = [
    # Token based authentication
    auth_type: :token_based, # mandatory, :token_based or :certificate_based
    token_id: :some_atom_id, # mandatory, token with the same id must be in `tokens` in `apns_config`
    # Connection config
    endpoint: "api.development.push.apple.com", # optional
    port: 443, # optional
    tls_opts: [], # optional
    ping_interval: 5000, # optional
    reconnect_attempts: 3, # optional
    # pool config
    tags: [:first_batch_clients, :beta_users], # optional
    worker_num: 3, # optional
    raw_opts: [], # optional
]
```

Certificate based authentication example:

```elixir
apns_pool = [
    # Certificate based authentication
    auth_type: :certificate_based, # mandatory, :token_based or :certificate_based
    cert: "path/to/apns/cert.pem", # mandatory, path to certificate file provided by APNS
    key: "path/to/apns/key.pem", # mandatory, path to key file provided by APNS
    # Connection config
    endpoint: "api.push.apple.com", # optional
    port: 443, # optional
    tls_opts: [], # optional
    ping_interval: 5000, # optional
    reconnect_attempts: 3, # optional
    # pool config
    tags: [:another_batch_clients], # optional
    worker_num: 3, # optional
    raw_opts: [] # optional
]
```

### APNS token example

```elixir
apns_token = [
          token_id: :some_atom_id, # mandatory, the same as in APNSPOOL
          key_id: "FAKE_KEY_ID", # mandatory, data obtained form APNS account
          team_id: "FAKE_TEAM_ID", # mandatory, data obtained form APNS account
          p8_file_path: "path/to/file/token.p8" # mandatory, path to file storing APNS token
        ]
```

## Include sparrow in your project

```elixir
defp deps do
    [
      {:sparrow, github: "esl/sparrow", tag: "cc80bbc"},
      ]
  end
```

## Many pools

Sparrow suports many pools in a single `:sparrow` instance.
[Tags](#tags) are used to choose a pool when sending a notification.


## Tags

Tags is a mechanism allowing to choose a pool to send a notification from.
Each pool has a defined list of tags (`[]` as default).
The algorithm has the following steps:
1) Filter pooltype based on notification type (`:fcm` or `:{apns, :dev}` or `{:apns, :prod}`).
2) Choose only pools that have all tags (from the function call) included in their tags (from pool configuration).
3) Choose first of the filtered pools.

Example:
    Let's say you have the following pools:

- `{:apns, :dev}`:
    - *pool1*: `[:test_pool, :dev_pool, :homer]`,
    - *pool2*: `[:test_pool, :dev_pool, :bart]`,
    - *pool3*: `[:test_pool, :dev_pool, :ned, :bart]`
- `{:apns, :prod}`:
    - *pool1*: `[:prod_pool]`


Lets assume the notification type is `{:apns, :dev}`.

If you pass `[]`, *pool1* is chosen. 

If you pass `[:homer]`, *pool1* is chosen. 

If you pass `[:bart]`, *pool2* is chosen. 

If you pass `[:ned]`, *pool3* is chosen. 

If you pass `[:test_pool]`, *pool1* is chosen. 

If you pass `[:test_pool, :homer]`, *pool1* is chosen. 

If you pass `[:test_pool, :dev_pool, :homer]`, *pool1* is chosen. 

If you pass `[:test_pool, :dev_pool, :ned]`, *pool3* is chosen. 

If you pass `[:not_existing, :set_of_tags]`, `{:error, :configuration_error}` is returned. 

[](https://placehold.it/15/ff0000/ff0000?text=+) *`It is not recommended to choose a pool based on pools order!`*

## Telemetry
Sparrow supports [telemetry](https://github.com/beam-telemetry/telemetry). Emitted events are defined with following tags:

- `[:sparrow, :h2_worker, :init]`
- `[:sparrow, :h2_worker, :terminate]`
- `[:sparrow, :h2_worker, :conn_lost]`
- `[:sparrow, :h2_worker, :request_error]`
- `[:sparrow, :h2_worker, :request_success]`
- `[:sparrow, :h2_worker, :conn_success]`
- `[:sparrow, :h2_worker, :conn_fail]`
- `[:sparrow, :pools_warden, :init]`
- `[:sparrow, :pools_warden, :terminate]`
- `[:sparrow, :pools_warden, :choose_pool]`
- `[:sparrow, :pools_warden, :pool_down]`
- `[:sparrow, :pools_warden, :add_pool]`

There are also events measuring the duration of a few chosen function calls:

- `[:sparrow, :push, :api]`
- `[:sparrow, :push, :apns]`
- `[:sparrow, :push, :fcm]`
- `[:sparrow, :h2_worker, :handle]`

# Send your first push notification

1) [Define your config](#build-sparrow-config)
2) Start an application
```elixir
Application.start(:sparrow)
```
3) Build and *Push* the notification
    3.1 APNS
    ```elixir
        :ok =
            "my_device_token"
            |> Sparrow.APNS.Notification.new(:dev)
            |> Sparrow.APNS.Notification.add_title("my first notification title")
            |> Sparrow.APNS.Notification.add_body("my first notification body")
            # |> Sparrow.APNS.Notification.add_...
            |> Sparrow.API.push()
    ```
    3.1 FCM
    ```elixir
    android =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("my first notification title")
        |> Sparrow.FCM.V1.Android.add_body("my first notification body")
    
    webpush = 
        Sparrow.FCM.V1.Webpush.new("www.my.test.link.com")
        |> Sparrow.FCM.V1.Webpush.add_title("my first notification title")
        |> Sparrow.FCM.V1.Webpush.add_body("my first notification body")
      
    notification =
        Sparrow.FCM.V1.Notification.new(:topic, "news")
        |> Sparrow.FCM.V1.Notification.add_android(android)
        |> Sparrow.FCM.V1.Notification.add_webpush(webpush)
        Sparrow.API.push()
    ```
    
***

## How to obtain and use APNS certificate for certificate based authorization?

Pre Requirements:
* MacOS with Xcode installed
* Apple mobile device
* Tutorial (*) requirements

First, follow [this](https://medium.com/flawless-app-stories/ios-remote-push-notifications-in-a-nutshell-d05f5ccac252) tutorial (*), specifically the "Step 3, get APNS certificate" section.

When you reach point where you have `exampleName.cer` file, import it to Keychain Access:
File -> Import Items... -> Chose `exampleName.cer` 

Next, export the certificate you just imported as `exampleName.p12`.
Note: you can just go with no password by pressing Enter. If you enter a password, remember it.
I shall refer to this password as (pass1) later in tutorial.

Open terminal, go to your `exampleName.p12` file location 
```sh
$ cd my/p12/file/location
```

Next convert `.p12` to `.pem`: 
```sh
$ openssl pkcs12 -in `exampleName.p12` -out `exampleName.pem`
```

Type (pass1), and then `exampleName.pem` file password (pass2), which cannot be empty.

Next extract key:

```sh
openssl rsa -in `exampleName.pem` -out `exampleKey.pem`
```

### How to obtain a device token?

Try [this](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).

### How to obtain an apns-topic?

Last but not least, to get the 'apns-topic' header value, go to:
Xcode -> open your swift app -> General -> Identity -> Bundle Identifier

Good luck :)
