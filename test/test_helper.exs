ExUnit.start(capture_log: true)

defmodule TestHelper do
  def restore_app_env() do
    Application.stop(:sparrow)
    Application.unload(:sparrow)
    Application.load(:sparrow)
    {:ok, _} = Application.ensure_all_started(:sparrow)
    :ok
  end
end

defmodule HelperMacros do
  defmacro __using__(_opts) do
    quote do
      @eventually_timeout 5000
      import unquote(__MODULE__)
    end
  end

defmacro eventually(truly) do
    quote do
      HelperMacros.wait_for(fn -> unquote truly end, @eventually_timeout)
    end
  end
def wait_for(fun, timeout) when timeout > 0 do
    timestep = 100
    case fun.() do
      true -> true
      false ->
        Process.sleep(timestep)
        wait_for(fun, timeout - timestep)
    end
  end
  def wait_for(fun, _timeout), do: fun.()
end
