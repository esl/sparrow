defmodule Helpers.CowboyHandlers.OkResponseHandler do
  def init(req, opts) do
    reply =
      :cowboy_req.reply(200, %{"content-type" => "application/json; charset=UTF-8"}, "", req)

    {:ok, reply, opts}
  end
end
