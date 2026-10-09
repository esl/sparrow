defmodule Sparrow.Authentication.CertificateBased do
  @moduledoc """
  Structure for cerificate based authentication.
  Use to create `Sparrow.Pool.Config`.
  """
  @type t :: %__MODULE__{
          certfile: Path.t(),
          keyfile: Path.t()
        }
  defstruct [
    :certfile,
    :keyfile
  ]

  @spec new(Path.t(), Path.t()) :: t
  def new(certfile, keyfile) do
    %__MODULE__{
      certfile: certfile,
      keyfile: keyfile
    }
  end
end
