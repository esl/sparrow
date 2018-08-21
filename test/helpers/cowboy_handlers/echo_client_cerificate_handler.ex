defmodule Helpers.CowboyHandlers.EchoClientCerificateHandler do
  @moduledoc false
  def init(req, opts) do
    subject =
      req
      |> :cowboy_req.cert()
      |> Helpers.CerificateHelper.get_subject_name_form_encoded_cert()

    reply =
      :cowboy_req.reply(
        200,
        %{
          "content-type" => "text/plain; charset=utf-8"
        },
        subject,
        req
      )

    {:ok, reply, opts}
  end
end
