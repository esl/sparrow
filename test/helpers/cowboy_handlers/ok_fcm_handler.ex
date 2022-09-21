defmodule Helpers.CowboyHandlers.OkFCMHandler do
  @moduledoc false
  def init(req, opts) do
    reply =
      :cowboy_req.reply(
        200,
        %{"content-type" => "application/json; charset=UTF-8"},
        "{
          \"name\": \"projects/myproject-b5ae1/messages/0:1500415314455276%31bd1c9631bd1c96\"
      }",
        req
      )

    {:ok, reply, opts}
  end
end
