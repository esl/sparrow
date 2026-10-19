defmodule Sparrow.APNS do
  @moduledoc """
  Provides functions to build and send push notifications to APNS
  """
  use Sparrow.Telemetry.Timer
  require Logger

  alias Sparrow.Request
  alias Sparrow.Util

  @type reason :: term
  @type headers :: Request.headers()
  @type body :: String.t()
  @type push_opts :: [{:is_sync, boolean()} | {:timeout, non_neg_integer}]
  @type http_status :: non_neg_integer
  @type authentication :: Sparrow.Pool.Config.authentication()
  @type tls_options :: Sparrow.Pool.Config.tls_options()
  @type time_in_miliseconds :: Sparrow.Pool.Config.time_in_miliseconds()
  @type port_num :: Sparrow.Pool.Config.port_num()
  @type sync_push_result :: {:ok, {headers, body}} | {:error, reason}

  @path "/3/device/"

  @doc """
  Sends the push notification to APNS.

  ## Options

    * `:is_sync` - whether to wait for the response, `true` by default
    * `:timeout` - time in milliseconds to send the request and get its response, 5000 by default

  ## Result

  `:ok` when the response has status 200, or when `:is_sync` is `false` and
  the request is handed over to the pool. Otherwise `{:error, reason}`, where
  `reason` comes from:

    * the pool, e.g. when there is no connection or no response in time, see
      `Sparrow.Pool.send_request/3` for all of them
    * APNS, when the status of the response is not 200 - the `reason` from
      its body, as an atom, e.g. `:BadDeviceToken`, see
      https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns

  ## Example

    #For more details on how to get device token and apns-topic go to project's ReadMe.
    @device_token "MYFAKEEXAMPLETOKENDEVICE"
    @apns_topic "MYFAKEEXAMPLEAPNSTOPIC"

    #Let's assume that `Sparrow.APNS.TokenBearer` is started
    config =
        "path/to/exampleName.pem"
        |> Sparrow.APNS.get_certificate_based_authentication("path/to/exampleKey.pem")
        |> Sparrow.APNS.get_pool_config_dev()
    {:ok, _pid} =
        Sparrow.Pool.start_link(%{config | name: :your_apns_pool_name})

    notification =
        @device_token
        |> Notification.new()
        |> Notification.add_title("example title")
        |> Notification.add_body("example body")
        |> Notification.add_apns_topic(@apns_topic)

    Sparrow.APNS.push(:your_apns_pool_name, notification)
  """

  @timed event_tags: [:push, :apns]
  @spec push(
          atom,
          Sparrow.APNS.Notification.t(),
          push_opts
        ) :: sync_push_result | :ok
  def push(pool, notification, opts) do
    is_sync = Keyword.get(opts, :is_sync, true)
    timeout = Keyword.get(opts, :timeout, 5_000)
    path = @path <> notification.device_token
    headers = notification.headers
    json_body = notification |> make_body() |> Jason.encode!()
    request = Request.new(headers, json_body, path, timeout)

    _ =
      Logger.debug("Sending APNS push notification",
        what: :apns_notification,
        request: request
      )

    pool
    |> Sparrow.Pool.send_request(request, is_sync)
    |> process_response()
  end

  def push(pool, notification),
    do: push(pool, notification, [])

  @doc """
  Parses the return headers and body in `push/2` returning the status code and reason in case of errors
  You can combine it with `Sparrow.APNS.get_error_description/1` to get a human-readable description of the error reason.
  Note that this function is used only if you push the notification in synchronous mode.

  ## Example

  push_result =
      pool
      |> Sparrow.APNS.push(notification)
  case push_result do
      :ok ->
          :ok
      {:error, {status, reason}} ->
          Sparrow.APNS.get_error_description(status, reason)
  end
  """
  @spec process_response(:ok | {:ok, {headers, body}} | {:error, reason}) ::
          :ok
          | {:error,
             reason ::
               String.t() | nil | :request_timeout | :connection_lost | reason}

  def process_response(:ok) do
    _ =
      Logger.debug("Processing async APNS notification response",
        what: :async_apns_push_response
      )

    :ok
  end

  def process_response({:ok, {headers, body}}) do
    if {":status", "200"} in headers do
      _ =
        Logger.debug("Processing APNS notification response",
          what: :apns_push_response,
          result: :success,
          status: "200"
        )

      :ok
    else
      reason =
        body
        |> get_reason_from_body()
        |> String.to_atom()

      _ =
        Logger.info("Processing APNS notification response",
          what: :apns_push_response,
          result: :error,
          reason: inspect(reason)
        )

      {:error, reason}
    end
  end

  def process_response({:error, reason}), do: {:error, reason}

  @doc """
  Function provides APNS errors description.

  Further details:
  https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW1
  Table 8-6 Values for the APNs JSON reason key

  ## Arguments

    * `code` - from http response proccess_response
  """
  @spec get_error_description(atom) :: String.t()
  def get_error_description(code) do
    Sparrow.APNS.Errors.get_error_description(code)
  end

  @doc """
  Builds an APNS notification payload.

  The `aps` dictionary is included only when the notification contains alert
  options or APS dictionary options. Data-only notifications are
  returned without an empty `aps` dictionary, which permits payload formats
  such as PushKit VoIP notifications.
  """
  @spec make_body(Sparrow.APNS.Notification.t()) :: map
  def make_body(notification) do
    alert =
      notification.alert_opts
      |> Map.new()

    aps_opts =
      notification.aps_dictionary_opts
      |> Map.new()
      |> Util.add_if_not_empty("alert", alert)

    notification.custom_data
    |> Map.new()
    |> Util.add_if_not_empty("aps", aps_opts)
  end

  @doc """
  Function providing `Sparrow.Authentication.TokenBased` for APNS pools.
  Requres `Sparrow.APNS.TokenBearer` to be started.
  """
  @spec get_token_based_authentication(atom) ::
          Sparrow.Authentication.TokenBased.t()
  def get_token_based_authentication(token_id) do
    getter = fn ->
      {"authorization",
       "bearer #{Sparrow.APNS.TokenBearer.get_token(token_id)}"}
    end

    Sparrow.Authentication.TokenBased.new(getter)
  end

  @doc """
  Function providing `Sparrow.Authentication.CertificateBased` for APNS pools.

  ##Arguments

    * `path_to_cert` - path to APNS certificate file
    * `path_to_key` - path to APNS key file
  """
  @spec get_certificate_based_authentication(Path.t(), Path.t()) ::
          Sparrow.Authentication.CertificateBased.t()
  def get_certificate_based_authentication(path_to_cert, path_to_key) do
    Sparrow.Authentication.CertificateBased.new(
      path_to_cert,
      path_to_key
    )
  end

  @doc """
  Function providing `Sparrow.Pool.Config` for APNS production pools.

  ## Example

  # Token based authentication:
    config =
      Sparrow.APNS.get_token_based_authentication()
      |> Sparrow.APNS.get_pool_config_prod()

  # Certificate based authentication:
    config =
      "path/to/certificate"
      |> Sparrow.APNS.get_certificate_based_authentication("path/to/key")
      |> Sparrow.APNS.get_pool_config_prod()

  """
  @spec get_pool_config_prod(
          authentication,
          String.t(),
          pos_integer,
          tls_options,
          time_in_miliseconds
        ) :: Sparrow.Pool.Config.t()
  def get_pool_config_prod(
        authentication,
        uri \\ "api.push.apple.com",
        port \\ 443,
        tls_opts \\ [],
        ping_interval \\ 5000
      ) do
    Sparrow.Pool.Config.new(%{
      type: {:apns, :prod},
      domain: uri,
      port: port,
      authentication: authentication,
      tls_options: tls_opts,
      ping_interval: ping_interval
    })
  end

  @doc """
  Function providing `Sparrow.Pool.Config` for APNS development pools.
  """
  @spec get_pool_config_dev(
          authentication,
          String.t(),
          pos_integer,
          tls_options,
          time_in_miliseconds
        ) :: Sparrow.Pool.Config.t()
  def get_pool_config_dev(
        authentication,
        uri \\ "api.development.push.apple.com",
        port \\ 443,
        tls_opts \\ [],
        ping_interval \\ 5000
      ) do
    Sparrow.Pool.Config.new(%{
      type: {:apns, :dev},
      domain: uri,
      port: port,
      authentication: authentication,
      tls_options: tls_opts,
      ping_interval: ping_interval
    })
  end

  @spec get_reason_from_body(String.t()) :: String.t() | nil
  defp get_reason_from_body(body) do
    body |> Jason.decode!() |> Map.get("reason")
  end
end
