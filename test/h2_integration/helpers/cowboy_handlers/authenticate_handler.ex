defmodule H2Integration.Helpers.CowboyHandlers.AuthenticateHandler do
  alias H2Integration.Helpers.TokenHelper, as: TokenHelper

  def init(req, opts) do
    reply = :cowboy_req.header("authorization", req) |> verify_token(req)
    {:ok, reply, opts}
  end

  defp verify_token(token, req) do
    correct_token = TokenHelper.get_correct_token()

    case token do
      ^correct_token ->
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/plain; charset=utf-8"},
          TokenHelper.get_correct_token_response_body(),
          req
        )

      _ ->
        :cowboy_req.reply(
          401,
          %{"content-type" => "text/plain; charset=utf-8"},
          TokenHelper.get_incorrect_token_response_body(),
          req
        )
    end
  end
end
