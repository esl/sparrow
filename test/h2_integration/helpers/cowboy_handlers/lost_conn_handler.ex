defmodule H2Integration.Helpers.CowboyHandlers.LostConnHandler do
  def init(req, opts) do
    :timer.sleep(2_000)
    reply = :cowboy_req.reply(200, %{"content-type" => "text/plain; charset=utf-8"}, "Hello", req)
    {:ok, reply, opts}
  end
end
