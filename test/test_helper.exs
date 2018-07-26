ExUnit.start()

defmodule FileExt do
  def ls_r(path \\ ".") do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        File.ls!(path)
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&ls_r/1)
        |> Enum.concat()

      true ->
        []
    end
  end
end

path_helpers = "test/h2_integration/helpers"

for path <- FileExt.ls_r(path_helpers) do
  Code.load_file(path)
end
