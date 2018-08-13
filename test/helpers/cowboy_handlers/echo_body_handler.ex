defmodule Helpers.CowboyHandlers.EchoBodyHandler do
  def init(req, opts) do
    {_, body, _} = :cowboy_req.read_body(req)

    reply =
      :cowboy_req.reply(200, %{"content-type" => "application/json; charset=UTF-8"}, body, req)

    {:ok, reply, opts}
  end
end
