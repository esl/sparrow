defmodule Helpers.CowboyHandlers.ErrorResponseHandler do
  @moduledoc false
  def init(req, opts) do
    {:ok, reason} = %{"reason" => "My error reason"} |> Jason.encode()

    reply =
      :cowboy_req.reply(
        321,
        %{"content-type" => "application/json; charset=UTF-8"},
        "#{reason}",
        req
      )

    {:ok, reply, opts}
  end
end
