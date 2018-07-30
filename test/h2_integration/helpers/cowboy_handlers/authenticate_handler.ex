defmodule H2Integration.Helpers.CowboyHandlers.AuthenticateHandler do
  alias H2Integration.Helpers.TokenHelper, as: TokenHelper

  def init(req, opts) do
    {code, answer} = :cowboy_req.header("authorization", req) |> verify_token_and_get_response()

    reply = :cowboy_req.reply(code, %{"content-type" => "text/plain; charset=utf-8"}, answer, req)

    {:ok, reply, opts}
  end

  defp verify_token_and_get_response(token) do
    correct_token = TokenHelper.get_correct_token()

    case token do
      ^correct_token -> {200, TokenHelper.get_correct_token_response_body()}
      _ -> {401, TokenHelper.get_incorrect_token_response_body()}
    end
  end
end
