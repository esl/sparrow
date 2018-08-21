defmodule Sparrow.H2Worker.Config do
  @moduledoc """
  Structure for H2Worker config.
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
          reconnect_attempts: pos_integer
        }

  defstruct [
    :domain,
    :port,
    :authentication,
    :tls_options,
    :ping_interval,
    :reconnect_attempts
  ]

  @doc """
  Function new creates h2 worker configuration.

  ## Arguments

    * `domain` - service address eg. "www.erlang-solutions.com"
    * `port` - port service works on,
    * `authentication` - a struct to provide token based or certificate based authentication
    * `tls_options` - See http://erlang.org/doc/man/ssl.html  ssl_option()
    * `ping_interval` - ping message is send to server periodically after ping_interval miliseconds (default 5_000)
    * `reconnect_attempts` - number of attempts to start connection before it fails (default 3)

  WARNING! If you use certificate based authentication do not add certfile and/or keyfile to `tls_options`, put them to `authentication`
  """
  @spec new(String.t(), port_num, tls_options, time_in_miliseconds, pos_integer) :: t
  def new(
        domain,
        port,
        authentication,
        tls_options \\ [],
        ping_interval \\ 5_000,
        reconnect_attempts \\ 3
      ) do
    %__MODULE__{
      domain: domain,
      port: port,
      authentication: authentication,
      tls_options: tls_options,
      ping_interval: ping_interval,
      reconnect_attempts: reconnect_attempts
    }
  end

  @spec get_authentication_type(__MODULE__.t()) :: :token_based | :certificate_based
  def get_authentication_type(config) do
    case config.authentication do
      %Sparrow.H2Worker.Authentication.TokenBased{} -> :token_based
      %Sparrow.H2Worker.Authentication.CertificateBased{} -> :certificate_based
    end
  end
end
