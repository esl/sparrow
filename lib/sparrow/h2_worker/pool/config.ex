defmodule Sparrow.H2Worker.Pool.Config do
  @moduledoc """
  Structure for starting `Sparrow.H2Worker.Pool`.
  """
  @type t :: %__MODULE__{
          pool_name: atom,
          workers_config: Sparrow.H2Worker.Config.t(),
          worker_num: pos_integer,
          raw_opts: [{atom, any}]
        }

  defstruct [
    :pool_name,
    :workers_config,
    :worker_num,
    :raw_opts
  ]

  @doc """
  Function `Sparrow.H2Worker.Pool.Config.new/2,3,4` creates workers pool configuration.

  ## Arguments

    * `workers_config` - config for each worker in pool. See `Sparrow.H2Worker.Config`. Config of a single worker for APNS see `Sparrow.APNS.get_h2worker_config_dev/1,2,3,4,5,6` and for FCM see `Sparrow.FCM.V1.get_h2worker_config/1,2,3,4,5,6`
    * `pool_name` - name of workers pool, when set to `nil` name is generated automatically
    * `worker_num` - number of workers in a pool
    * `raw_opts` - extra config options to pass to wpool. For details see https://github.com/inaka/worker_pool
  """
  @spec new(Sparrow.H2Worker.Config.t(), atom | nil, pos_integer, [{atom, any}]) ::
          t
  def new(
        workers_config,
        pool_name \\ nil,
        worker_num \\ 3,
        raw_opts \\ []
      )

  def new(
        workers_config,
        nil,
        worker_num,
        raw_opts
      ) do
    %__MODULE__{
      pool_name: random_atom(20),
      workers_config: workers_config,
      worker_num: worker_num,
      raw_opts: raw_opts
    }
  end

  def new(
        workers_config,
        pool_name,
        worker_num,
        raw_opts
      ) do
    %__MODULE__{
      pool_name: pool_name,
      workers_config: workers_config,
      worker_num: worker_num,
      raw_opts: raw_opts
    }
  end

  @chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("")

  defp random_atom(len) do
    1..len
    |> Enum.reduce([], fn _i, acc ->
      [Enum.random(@chars) | acc]
    end)
    |> Enum.join("")
    |> String.to_atom()
  end
end
