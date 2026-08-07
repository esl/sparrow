defmodule Mix.Tasks.Sparrow.Certs.Dev do
  @moduledoc """
  Generate fake certs (placeholders) for `HTTPS` endpoint and `APNS` service.

  Please be aware that `APNS` requires valid Apple Developer certificates, so it
  will not accept those fake certificates. Generated certificates may be used
  only with mock APNS service (like one provided by docker
  `mobify/apns-http2-mock-server`).
  """
  @shortdoc "Generate fake certs (placeholders) for HTTPS endpoint and APNS"

  use Mix.Task

  # From: https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html
  @apns_topic_extn_id {1, 2, 840, 113_635, 100, 6, 3, 6}
  # Here we use the binary extension extracted from real APNS certificate.
  # It's much better for testing to use
  # the real extension instead of a generated one since,
  # the genertor would be based on reverse-engineered structure that may not be correct.
  # Also testing decoding on extesion encoded using the same encoder is kinda pointless.
  @apns_topic_extn_value <<48, 129, 133, 12, 26, 99, 111, 109, 46, 105, 110, 97,
                           107, 97, 110, 101, 116, 119, 111, 114, 107, 115, 46,
                           77, 97, 110, 103, 111, 115, 116, 97, 48, 5, 12, 3,
                           97, 112, 112, 12, 31, 99, 111, 109, 46, 105, 110, 97,
                           107, 97, 110, 101, 116, 119, 111, 114, 107, 115, 46,
                           77, 97, 110, 103, 111, 115, 116, 97, 46, 118, 111,
                           105, 112, 48, 6, 12, 4, 118, 111, 105, 112, 12, 39,
                           99, 111, 109, 46, 105, 110, 97, 107, 97, 110, 101,
                           116, 119, 111, 114, 107, 115, 46, 77, 97, 110, 103,
                           111, 115, 116, 97, 46, 99, 111, 109, 112, 108, 105,
                           99, 97, 116, 105, 111, 110, 48, 14, 12, 12, 99, 111,
                           109, 112, 108, 105, 99, 97, 116, 105, 111, 110>>

  @spec run(term) :: :ok
  def run(_) do
    maybe_gen_apns_token()
    maybe_gen_dev_apns()
    maybe_gen_prod_apns()
    maybe_gen_https()
    maybe_gen_wildcard_https()
    maybe_gen_test_client()
  end

  defp maybe_gen_dev_apns do
    maybe_gen_cert(
      "priv/apns/dev_cert.pem",
      "priv/apns/dev_key.pem",
      "sparrow-apns-dev"
    )
  end

  defp maybe_gen_test_client do
    maybe_gen_cert(
      "priv/ssl/client_cert.pem",
      "priv/ssl/client_key.pem",
      "client"
    )
  end

  defp maybe_gen_prod_apns do
    extensions = [
      {@apns_topic_extn_id, @apns_topic_extn_value}
    ]

    maybe_gen_cert(
      "priv/apns/prod_cert.pem",
      "priv/apns/prod_key.pem",
      "sparrow-apns-prod",
      extensions
    )
  end

  defp maybe_gen_https do
    maybe_gen_cert(
      "priv/ssl/fake_cert.pem",
      "priv/ssl/fake_key.pem",
      "sparrow"
    )
  end

  # Covers "*.sparrow.test" by a wildcard SAN only, mirroring the certificate
  # Google serves for "fcm.googleapis.com". Used to test that the default TLS
  # options accept wildcard certificates. Issued by its own small CA because
  # `:ssl` rejects a self-signed peer certificate outright, before it ever gets
  # as far as checking the hostname.
  defp maybe_gen_wildcard_https do
    ca_cert = "priv/ssl/wildcard_ca_cert.pem"
    ca_key = "priv/ssl/wildcard_ca_key.pem"

    maybe_gen_cert(
      ca_cert,
      ca_key,
      "sparrow-test-ca",
      [{"basicConstraints", "critical,CA:TRUE"}]
    )

    maybe_gen_cert(
      "priv/ssl/wildcard_cert.pem",
      "priv/ssl/wildcard_key.pem",
      "*.sparrow.test",
      [{"subjectAltName", "DNS:*.sparrow.test"}],
      {ca_cert, ca_key}
    )
  end

  defp maybe_gen_cert(
         cert_file,
         key_file,
         common_name,
         extensions \\ [],
         signer \\ :self
       ) do
    if File.exists?(cert_file) and File.exists?(key_file) do
      :ok
    else
      gen_cert(cert_file, key_file, common_name, extensions, signer)
    end
  end

  defp gen_cert(cert_file, key_file, common_name, extensions, signer) do
    cert_dir = Path.dirname(cert_file)
    key_dir = Path.dirname(key_file)

    :ok = File.mkdir_p(cert_dir)
    :ok = File.mkdir_p(key_dir)

    ext_file = openssl_tmp_extfile(extensions)

    req_file = create_csr!(common_name, key_file, cert_file)
    :ok = sign_csr!(req_file, key_file, ext_file, cert_file, signer)

    :ok = File.rm!(ext_file)
    :ok = File.rm!(req_file)
  end

  defp create_csr!(common_name, key_file, cert_file) do
    req_file = cert_file <> ".csr"

    {_, 0} =
      System.cmd("openssl", [
        "req",
        "-new",
        "-nodes",
        "-days",
        "365",
        "-subj",
        "/C=PL/ST=ML/L=Krakow/CN=" <> common_name,
        "-newkey",
        "rsa:2048",
        "-keyout",
        key_file,
        "-out",
        req_file
      ])

    req_file
  end

  defp sign_csr!(req_file, key_file, ext_file, cert_file, signer) do
    {_, 0} =
      System.cmd(
        "openssl",
        [
          "x509",
          "-req",
          "-days",
          "365",
          "-in",
          req_file,
          "-extfile",
          ext_file,
          "-out",
          cert_file
        ] ++ signer_args(signer, key_file)
      )

    :ok
  end

  # Either self-signed with the certificate's own key, or issued by a CA.
  defp signer_args(:self, key_file) do
    ["-signkey", key_file]
  end

  defp signer_args({ca_cert_file, ca_key_file}, _key_file) do
    ["-CA", ca_cert_file, "-CAkey", ca_key_file, "-CAcreateserial"]
  end

  defp openssl_tmp_extfile(extensions) do
    ext_file = Path.join("/tmp", UUID.uuid4())
    # Make sure the file exists even if there are no extensions
    _ = File.touch(ext_file)

    for extension <- extensions do
      :ok = File.write!(ext_file, extension_line(extension), [:append])
    end

    ext_file
  end

  # Extensions are given either as {oid_tuple, der_binary}, written out in
  # OpenSSL's DER form, or as {name, value} strings written out verbatim.
  defp extension_line({ext_id, ext_bin}) when is_tuple(ext_id) do
    ~s"#{extn_id_to_string(ext_id)}=DER:#{Base.encode16(ext_bin)}\n"
  end

  defp extension_line({ext_name, ext_value}) when is_binary(ext_name) do
    ~s"#{ext_name}=#{ext_value}\n"
  end

  defp extn_id_to_string(extn_id) do
    extn_id
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp maybe_gen_apns_token do
    case System.cmd("openssl", [
           "ecparam",
           "-name",
           "secp256r1",
           "-genkey",
           "-noout",
           "-out",
           "token.p8"
         ]) do
      {"", 0} ->
        :ok

      reason ->
        raise "Cannot generate p8 private key!!! Reason: #{inspect(reason)}"
    end
  end
end
