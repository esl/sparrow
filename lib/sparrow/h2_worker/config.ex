defmodule Sparrow.H2Worker.Config do
  @moduledoc """
  Structure for `Sparrow.H2Worker` config.
  """
  @type time_in_miliseconds :: non_neg_integer
  @type port_num :: non_neg_integer
  @type tls_options :: [any]
  @type authentication ::
          Sparrow.H2Worker.Authentication.TokenBased.t()
          | Sparrow.H2Worker.Authentication.CertificateBased.t()

  @type t :: %__MODULE__{
          domain: String.t(),
          port: non_neg_integer,
          authentication: authentication,
          tls_options: tls_options,
          ping_interval: time_in_miliseconds | nil,
          reconnect_attempts: pos_integer,
          backoff_initial_delay: pos_integer,
          backoff_max_delay: pos_integer,
          backoff_base: pos_integer,
          pool_type: Sparrow.PoolsWarden.pool_type(),
          pool_name: atom,
          pool_tags: [atom],
          connections: pos_integer
        }

  defstruct [
    :domain,
    :port,
    :authentication,
    :tls_options,
    :ping_interval,
    :reconnect_attempts,
    :backoff_initial_delay,
    :backoff_max_delay,
    :backoff_base,
    :pool_type,
    :pool_name,
    :pool_tags,
    :connections
  ]

  @doc """
  Function new creates h2 worker configuration.

  ## Arguments

    * `domain` - service address eg. "www.erlang-solutions.com"
    * `port` - port service works on,
    * `authentication` - a struct to provide token based or certificate based authentication
    * `tls_options` - See http://erlang.org/doc/man/ssl.html  ssl_option()
    * `ping_interval` - ping is sent to server after the connection was idle for ping_interval miliseconds,
      `nil` switches it off (default 5_000)
    * `connections` - number of connections, set by `Sparrow.H2Worker.Pool` to the size of the pool (default 1)
    * `reconnect_attempts`, `backoff_base`, `backoff_initial_delay`, `backoff_max_delay` - not used,
      the connection is reestablished by the HTTP/2 client on its own

  WARNING! If you use certificate based authentication do not add certfile and/or keyfile to `tls_options`, put them to `authentication`
  """
  @spec new(map) :: t
  def new(specific) do
    %{
      domain: domain,
      port: port,
      authentication: authentication,
      tls_options: tls_options,
      ping_interval: ping_interval,
      reconnect_attempts: reconnect_attempts,
      backoff_initial_delay: backoff_initial_delay,
      backoff_max_delay: backoff_max_delay,
      backoff_base: backoff_base,
      pool_type: pool_type,
      pool_name: pool_name,
      pool_tags: pool_tags,
      connections: connections
    } = Map.merge(default(), specific)

    %__MODULE__{
      domain: domain,
      port: port,
      authentication: authentication,
      tls_options: tls_options,
      ping_interval: ping_interval,
      reconnect_attempts: reconnect_attempts,
      backoff_initial_delay: backoff_initial_delay,
      backoff_max_delay: backoff_max_delay,
      backoff_base: backoff_base,
      pool_type: pool_type,
      pool_name: pool_name,
      pool_tags: pool_tags,
      connections: connections
    }
  end

  defp default do
    %{
      tls_options: [],
      ping_interval: 5_000,
      reconnect_attempts: 3,
      backoff_base: 2,
      backoff_initial_delay: 100,
      backoff_max_delay: 5000,
      pool_type: nil,
      pool_name: nil,
      pool_tags: [],
      connections: 1
    }
  end

  @doc """
  Description of the pool the config belongs to, used in telemetry events.
  """
  @spec pool_info(t) :: map
  def pool_info(config) do
    %{
      domain: config.domain,
      port: config.port,
      pool_type: config.pool_type,
      pool_name: config.pool_name,
      pool_tags: config.pool_tags
    }
  end

  @doc """
  TLS options of the connection, including the client certificate
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
      %Sparrow.H2Worker.Authentication.TokenBased{} -> :token_based
      %Sparrow.H2Worker.Authentication.CertificateBased{} -> :certificate_based
    end
  end
end
