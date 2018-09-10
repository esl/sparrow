defmodule Sparrow.H2Worker.Pool.Config do
  @moduledoc """
  Structure for starting `Sparrow.H2Worker.Pool`.
  """
  @type t :: %__MODULE__{
          wpool_name: atom,
          workers_config: Sparrow.H2Worker.Config.t(),
          worker_num: pos_integer,
          raw_opts: [{atom, any}]
        }

  defstruct [
    :wpool_name,
    :workers_config,
    :worker_num,
    :raw_opts
  ]

  @doc """
  Function `new/2,3,4` creates workers pool configuration.

  ## Arguments

    * `wpool_name` - name of workers pool
    * `workers_config` - config for each worker in pool. See `Sparrow.H2Worker.Config`
    * `worker_num` - number of workers in a pool
    * `raw_opts` - config options passed to wpool
  """
  @spec new(atom, Sparrow.H2Worker.Config.t(), pos_integer, [{atom, any}]) :: t
  def new(
        wpool_name,
        workers_config,
        worker_num \\ 3,
        raw_opts \\ []
      ) do
    %__MODULE__{
      wpool_name: wpool_name,
      workers_config: workers_config,
      worker_num: worker_num,
      raw_opts: raw_opts
    }
  end
end
