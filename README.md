# Sparrow

**TODO: Add description**

**TODO: Redirect Erlang lager to Elixir logger**

**TODO: Add publishing package to hex** 

## Installation

[![Build Status](https://travis-ci.com/aleklisi/sparrow.svg?branch=master)](https://travis-ci.com/aleklisi/sparrow)
[![Coverage Status](https://coveralls.io/repos/github/aleklisi/sparrow/badge.svg)](https://coveralls.io/github/aleklisi/sparrow)

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sparrow` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sparrow, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sparrow](https://hexdocs.pm/sparrow).

## How to obtain and use APNS certificate for certificate based authorization?

Pre Requirements:
* MacOS with Xcode installed
* Apple mobile device
* Tutorial (*) requirements

First, follow [this](https://medium.com/flawless-app-stories/ios-remote-push-notifications-in-a-nutshell-d05f5ccac252) tutorial (*), specifically the "Step 3, get APNS certificate" section.

When you reach point where you have `exampleName.cer` file, import it to Keychain Access:
File -> Import Items... -> Chose `exampleName.cer` 

Next, export the certificate you just imported as `exampleName.p12`.
Note: you can just go with empty password by pressing Enter. If you enter a password rememeber it.
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

When starting  h2 worker pass key and cerificate to workers tls options:

```elixir
tls_opts = [
  {:certfile, "path/to/exampleName.pem"},
  {:keyfile, "path/to/exampleKey.pem"}
] 
config = Sparrow.H2Worker.Config.new("api.development.push.apple.com", 443, tls_opts)
Sparrow.H2Worker.start_link(:your_apns_workers_name, config)
```

## How to obtain device token??

Try [this](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns).

## How to obtain apns-topic??

Last but not least, to get the 'apns-topic' header value, go to:
Xcode -> open your swift app -> General -> Identity -> Bundle Identifier

Good luck :)
