defmodule Helpers.CowboyHandlers.EchoClientCerificateHandler do
  def init(req, opts) do
    subject =
      :cowboy_req.cert(req)
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
