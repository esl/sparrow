defmodule H2Integration.Helpers.CowboyHandlers.HeaderToBodyEchoHandler do
  def init(req0, opts) do
    method = :cowboy_req.method(req0)
    req = maybe_echo(method, req0)
    {:ok, req, opts}
  end

  defp maybe_echo("POST", req) do
    allheaders = :cowboy_req.headers(req)
    echo("#{inspect(allheaders)}", req)
  end

  defp echo(echo, req) do
    :cowboy_req.reply(
      200,
      %{
        "content-type" => "text/plain; charset=utf-8"
      },
      echo,
      req
    )
  end
end
