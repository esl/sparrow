defmodule Sparrow.Pool.Config do
  @moduledoc """
  Structure for `Sparrow.Pool` config.
  """
  @type time_in_miliseconds :: non_neg_integer
  @type port_num :: non_neg_integer
  @type tls_options :: [any]
  @type authentication ::
          Sparrow.Authentication.TokenBased.t()
          | Sparrow.Authentication.CertificateBased.t()

  @type type :: :fcm | {:apns, :dev} | {:apns, :prod}

  @type t :: %__MODULE__{
          name: atom,
          type: type | nil,
          tags: [atom],
          domain: String.t(),
          port: port_num,
          authentication: authentication,
          tls_options: tls_options,
          connections: pos_integer,
          ping_interval: time_in_miliseconds | nil
        }

  defstruct [
    :name,
    :type,
    :tags,
    :domain,
    :port,
    :authentication,
    :tls_options,
    :connections,
    :ping_interval
  ]

  @doc """
  Function new creates pool configuration.

  ## Arguments

    * `domain` - service address eg. "www.erlang-solutions.com"
    * `port` - port service works on,
    * `authentication` - a struct to provide token based or certificate based authentication
    * `name` - name of the pool, generated when not set
    * `type` - `:fcm`, `{:apns, :dev}` or `{:apns, :prod}`, allows `Sparrow.Pool.choose/2` to find the pool
    * `tags` - tags allowing `Sparrow.Pool.choose/2` to find the pool (default `[]`)
    * `connections` - number of connections (default 3)
    * `tls_options` - See http://erlang.org/doc/man/ssl.html  ssl_option()
    * `ping_interval` - ping is sent to server after a connection was idle for ping_interval miliseconds,
      `nil` switches it off (default 5_000)

  WARNING! If you use certificate based authentication do not add certfile and/or keyfile to `tls_options`, put them to `authentication`
  """
  @spec new(map) :: t
  def new(specific) do
    config = %__MODULE__{} = struct!(__MODULE__, Map.merge(default(), specific))
    %{config | name: config.name || random_atom(20)}
  end

  defp default do
    %{
      name: nil,
      type: nil,
      tags: [],
      tls_options: [],
      connections: 3,
      ping_interval: 5_000
    }
  end

  @doc """
  Description of the pool, used in telemetry events.
  """
  @spec pool_info(t) :: map
  def pool_info(config) do
    %{
      domain: config.domain,
      port: config.port,
      pool_type: config.type,
      pool_name: config.name,
      pool_tags: config.tags
    }
  end

  @doc """
  TLS options of the connections, including the client certificate
  for certificate based authentication.
  """
  @spec connection_tls_options(t) :: tls_options
  def connection_tls_options(config) do
    case get_authentication_type(config) do
      :certificate_based ->
        [
          {:certfile, config.authentication.certfile},
          {:keyfile, config.authentication.keyfile} | config.tls_options
        ]

      :token_based ->
        config.tls_options
    end
  end

  @spec get_authentication_type(__MODULE__.t()) ::
          :token_based | :certificate_based
  def get_authentication_type(config) do
    case config.authentication do
      %Sparrow.Authentication.TokenBased{} -> :token_based
      %Sparrow.Authentication.CertificateBased{} -> :certificate_based
    end
  end

  @chars String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true)

  defp random_atom(len) do
    1..len
    |> Enum.map_join(fn _i -> Enum.random(@chars) end)
    |> String.to_atom()
  end
end
