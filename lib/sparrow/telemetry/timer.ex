defmodule Sparrow.Telemetry.Timer do
  @moduledoc """
  Module responsible for handling emitting telemetry events which measure time of execution
  """
  require Logger

  defmacro __using__(_mod) do
    quote do
      import Sparrow.Telemetry.Timer
      Module.register_attribute(__MODULE__, :timed_functions, accumulate: true)
      @on_definition Sparrow.Telemetry.Timer
      @before_compile Sparrow.Telemetry.Timer
    end
  end

  def __on_definition__(env, _kind, name, args, guards, body) do
    module = env.module
    time_info = Module.get_attribute(module, :timed)

    if time_info do
      event_tags = time_info[:event_tags]

      Module.put_attribute(module, :timed_functions, %{
        event_tags: event_tags,
        name: name,
        args: args,
        guards: guards,
        body: body
      })

      Module.delete_attribute(module, :timed)
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    timed_funs = Module.get_attribute(module, :timed_functions)

    new_funs =
      timed_funs
      |> Enum.map(fn fun_info ->
        :ok =
          Module.make_overridable(module, [
            {fun_info.name, length(fun_info.args)}
          ])

        new_body = update_body(fun_info)

        if length(fun_info.guards) > 0 do
          quote generated: true do
            def unquote(fun_info.name)(unquote_splicing(fun_info.args))
                when unquote_splicing(fun_info.guards) do
              unquote(new_body)
            end
          end
        else
          quote generated: true do
            def unquote(fun_info.name)(unquote_splicing(fun_info.args)) do
              unquote(new_body)
            end
          end
        end
      end)

    quote do
      (unquote_splicing(new_funs))
    end
  end

  defp update_body(fun_info) do
    quote do
      t_start = Time.utc_now()
      res = unquote(Keyword.get(fun_info.body, :do))
      t_end = Time.utc_now()
      t = abs(Time.diff(t_start, t_end, :microsecond))

      :telemetry.execute(
        [:sparrow | unquote(fun_info.event_tags)],
        %{
          time: t
        },
        %{
          args: unquote(fun_info.args)
        }
      )

      res
    end
  end
end
