defmodule H2Integration.Helpers.CerificateHelper do
  require Record

  Record.defrecord(
    :otp_cert,
    Record.extract(:OTPCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :tbs_cert,
    Record.extract(:OTPTBSCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :cert_attr,
    Record.extract(:AttributeTypeAndValue, from_lib: "public_key/include/public_key.hrl")
  )

  def get_subject_name_form_encoded_cert(cert) do
    {:OTPCertificate, cert, _, _} = :public_key.pkix_decode_cert(cert, :otp)

    cert
    |> tbs_cert(:subject)
    |> parse_subject_name()
  end

  def get_subject_name_form_not_encoded_cert(pem_bin) do
    [{:Certificate, binary_cert, :not_encrypted}] = :public_key.pem_decode(pem_bin)
    {:OTPCertificate, cert, _, _} = :public_key.pkix_decode_cert(binary_cert, :otp)

    cert
    |> tbs_cert(:subject)
    |> parse_subject_name()
  end

  defp parse_subject_name({:rdnSequence, rdn_sequence}) do
    rdn_sequence
    |> List.flatten()
    # Get value for each RDN
    |> Enum.map(&cert_attr(&1, :value))
    |> Enum.map(&normalize_rdn_string/1)
    |> List.insert_at(0, "")
    |> Enum.join("/")
  end

  defp normalize_rdn_string({_string_type, name}), do: normalize_rdn_string(name)
  defp normalize_rdn_string(name), do: ~s"#{name}"
end
