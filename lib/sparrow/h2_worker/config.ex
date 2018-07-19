defmodule Sparrow.H2Worker.Config do
  @type time_in_miliseconds :: non_neg_integer
  @type port_num :: non_neg_integer
  @type tls_options :: [any]

  @type t :: %__MODULE__{
          domain: String.t(),
          port: non_neg_integer,
          tls_options: tls_options,
          ping_interval: time_in_miliseconds | nil
        }

  @doc !"""
       Structure for H2Worker config.
       """
  defstruct [
    :domain,
    :port,
    :tls_options,
    :ping_interval
  ]

  @spec new(String.t(), port_num, tls_options, time_in_miliseconds) :: t
  def new(domain, port, tls_options \\ [], timeout \\ 5_000) do
    %__MODULE__{
      domain: domain,
      port: port,
      tls_options: tls_options,
      ping_interval: timeout
    }
  end
end
