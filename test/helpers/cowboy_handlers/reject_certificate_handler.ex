defmodule Helpers.CowboyHandlers.RejectCertificateHandler do
  @moduledoc false
  def init(req, opts) do
    reply =
      :cowboy_req.reply(
        495,
        %{"content-type" => "text/plain; charset=utf-8"},
        "Hello",
        req
      )

    {:ok, reply, opts}
  end
end
