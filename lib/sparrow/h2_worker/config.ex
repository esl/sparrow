defmodule Sparrow.H2Worker.Config do
  @type time_in_miliseconds :: non_neg_integer
  @type port_num :: non_neg_integer
  @type tls_options :: [any]

  @type t :: %__MODULE__{
          domain: String.t(),
          port: non_neg_integer,
          tls_options: tls_options,
          ping_interval: time_in_miliseconds | nil,
          reconnect_attempts: pos_integer
        }

  @doc !"""
       Structure for H2Worker config.
       """
  defstruct [
    :domain,
    :port,
    :tls_options,
    :ping_interval,
    :reconnect_attempts
  ]

  @spec new(String.t(), port_num, tls_options, time_in_miliseconds, pos_integer) :: t
  def new(domain, port, tls_options \\ [], ping_interval \\ 5_000, reconnect_attempts \\ 3) do
    %__MODULE__{
      domain: domain,
      port: port,
      tls_options: tls_options,
      ping_interval: ping_interval,
      reconnect_attempts: reconnect_attempts
    }
  end
end
