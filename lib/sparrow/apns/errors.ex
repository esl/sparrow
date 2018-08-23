defmodule Sparrow.APNS.Errors do
  @moduledoc false

  @spec get_error_description(non_neg_integer, String.t()) :: String.t()
  def get_error_description(400, "BadCollapseId"),
    do: "The collapse identifier exceeds the maximum allowed size."

  def get_error_description(400, "BadDeviceToken"),
    do:
      "The specified device token was bad.
      Verify that the request contains a valid token and that the token matches the environment."

  def get_error_description(400, "BadExpirationDate"),
    do: "The apns-expiration value is bad."

  def get_error_description(400, "BadMessageId"),
    do: "The apns-id value is bad."

  def get_error_description(400, "BadPriority"),
    do: "The apns-priority value is bad."

  def get_error_description(400, "BadTopic"), do: "The apns-topic was invalid."

  def get_error_description(400, "DeviceTokenNotForTopic"),
    do: "The device token does not match the specified topic."

  def get_error_description(400, "DuplicateHeaders"),
    do: "One or more headers were repeated."

  def get_error_description(400, "IdleTimeout"), do: "Idle time out."

  def get_error_description(400, "MissingDeviceToken"),
    do: "The device token is not specified in the request :path.
      Verify that the :path header contains the device token."

  def get_error_description(400, "MissingTopic"),
    do:
      "The apns-topic header of the request was not specified and was required.
      The apns-topic header is mandatory when the client is connected
      using a certificate that supports multiple topics."

  def get_error_description(400, "PayloadEmpty"),
    do: "The message payload was empty."

  def get_error_description(400, "TopicDisallowed"),
    do: "Pushing to this topic is not allowed."

  def get_error_description(403, "BadCertificate"),
    do: "The certificate was bad."

  def get_error_description(403, "BadCertificateEnvironment"),
    do: "The client certificate was for the wrong environment."

  def get_error_description(403, "ExpiredProviderToken"),
    do: "The provider token is stale and a new token should be generated."

  def get_error_description(403, "Forbidden"),
    do: "The specified action is not allowed."

  def get_error_description(403, "InvalidProviderToken"),
    do:
      "The provider token is not valid or the token signature could not be verified."

  def get_error_description(403, "MissingProviderToken"),
    do: "No provider certificate was used to connect to APNs and Authorization
      header was missing or no provider token was specified."

  def get_error_description(404, "BadPath"),
    do: "The request contained a bad :path value."

  def get_error_description(405, "MethodNotAllowed"),
    do: "The specified :method was not POST."

  def get_error_description(410, "Unregistered"),
    do: "The device token is inactive for the specified topic."

  def get_error_description(413, "PayloadTooLarge"),
    do:
      "The message payload was too large.
      See Creating the Remote Notification Payload for details on maximum payload size."

  def get_error_description(429, "TooManyProviderTokenUpdates"),
    do: "The provider token is being updated too often."

  def get_error_description(429, "TooManyRequests"),
    do: "Too many requests were made consecutively to the same device token."

  def get_error_description(500, "InternalServerError"),
    do: "An internal server error occurred."

  def get_error_description(503, "ServiceUnavailable"),
    do: "The service is unavailable."

  def get_error_description(503, "Shutdown"), do: "The server is shutting down."

  def get_error_description(status_code, error_string),
    do:
      "Unmatched status code  = #{status_code}, error string = #{error_string}"
end
