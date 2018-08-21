defmodule Sparrow.H2Worker.Authentication.CertificateBased do
  @moduledoc """
  Structure for cerificate based authentication.
  Use to create Config for H2Worker.
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
