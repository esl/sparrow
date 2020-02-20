defmodule Sparrow.APNS do
  @moduledoc """
  Provides functions to build and send push notifications to APNS
  """
  use Sparrow.Telemetry.Timer
  require Logger

  alias Sparrow.H2Worker.Request

  @type reason :: atom
  @type headers :: Request.headers()
  @type body :: String.t()
  @type state :: Sparrow.H2Worker.State.t()
  @type push_opts :: [{:is_sync, boolean()} | {:timeout, non_neg_integer}]
  @type http_status :: non_neg_integer
  @type authentication :: Sparrow.H2Worker.Config.authentication()
  @type tls_options :: Sparrow.H2Worker.Config.tls_options()
  @type time_in_miliseconds :: Sparrow.H2Worker.Config.time_in_miliseconds()
  @type port_num :: Sparrow.H2Worker.Config.port_num()
  @type sync_push_result ::
          {:error, :connection_lost}
          | {:ok, {headers, body}}
          | {:error, :request_timeout}
          | {:error, :not_ready}
          | {:error, :invalid_notification}
          | {:error, reason}

  @path "/3/device/"

  @doc """
  Sends the push notification to APNS.

  ## Options

  * `:is_sync` - Determines whether the worker should wait for response after sending the request. When set to `true` (default), the result of calling this functions is one of:
      * `:ok` when the response is received.
      * `{:error, :request_timeout}` when the response doesn't arrive until timeout occurs (see the `:timeout` option).
      * `{:error, :connection_lost}` when the connection to APNS is lost before the response arrives.
      * `{:error, :not_ready}` when stream response is not yet ready, but it h2worker tries to get it.
      * `{:error, :invalid_notification}` when notification does not contain neither title nor body.
      * `{:error, :reason}` when error with other reason occures.
    * `:timeout` - Request timeout in milliseconds. Defaults value is 5000.

  ## Example

    #For more details on how to get device token and apns-topic go to project's ReadMe.
    @device_token "MYFAKEEXAMPLETOKENDEVICE"
    @apns_topic "MYFAKEEXAMPLEAPNSTOPIC"

    #Let's assume that `Sparrow.APNS.TokenBearer` is started
    config =
        "path/to/exampleName.pem"
        |> Sparrow.APNS.get_certificate_based_authentication("path/to/exampleKey.pem")
        |> Sparrow.APNS.get_h2worker_config_dev()
    {:ok, _pid} =
        config
        |> Sparrow.H2Worker.Pool.Config.new(:your_apns_workers_name)
        |> Sparrow.H2Worker.Pool.start_unregistered({:apns, :dev})

    notification =
        @device_token
        |> Notification.new()
        |> Notification.add_title("example title")
        |> Notification.add_body("example body")
        |> Notification.add_apns_topic(@apns_topic)

    Sparrow.APNS.push(:your_apns_workers_name, notification)
  """

  @timed event_name: :apns_push
  @spec push(
          atom,
          Sparrow.APNS.Notification.t(),
          push_opts
        ) :: sync_push_result | :ok
  def push(h2_worker_pool, notification, opts) do
    is_sync = Keyword.get(opts, :is_sync, true)
    timeout = Keyword.get(opts, :timeout, 5_000)
    strategy = Keyword.get(opts, :strategy, :random_worker)
    path = @path <> notification.device_token
    headers = notification.headers
    json_body = notification |> make_body() |> Jason.encode!()
    request = Request.new(headers, json_body, path, timeout)

    _ =
      Logger.debug(fn ->
        "action=push_apns_notification, request=#{inspect(request)}"
      end)

    h2_worker_pool
    |> Sparrow.H2Worker.Pool.send_request(
      request,
      is_sync,
      timeout,
      strategy
    )
    |> process_response()
  end

  def push(h2_worker_pool, notification),
    do: push(h2_worker_pool, notification, [])

  @doc """
  Parses the return headers and body in `push/2` returning the status code and reason in case of errors
  You can combine it with `Sparrow.APNS.get_error_description/1` to get a human-readable description of the error reason.
  Note that this function is used only if you push the notification in synchronous mode.

  ## Example

  push_result =
      worker
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
             reason :: String.t() | nil | :request_timeout | :not_ready | reason}

  def process_response(:ok) do
    _ = Logger.debug(fn -> "action=handle_async_push_response" end)
    :ok
  end

  def process_response({:ok, {headers, body}}) do
    if {":status", "200"} in headers do
      _ =
        Logger.debug(fn ->
          "action=handle_push_response, result=succes, status=200"
        end)

      :ok
    else
      reason =
        body
        |> get_reason_from_body()
        |> String.to_atom()

      _ =
        Logger.info(fn ->
          "action=handle_push_response, result=fail, reason=#{inspect(reason)}"
        end)

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
  Function to make APNS notifiaction payload.
  """
  @spec make_body(Sparrow.APNS.Notification.t()) :: map
  def make_body(notification) do
    alert =
      notification.alert_opts
      |> Map.new()

    aps_opts =
      notification.aps_dictionary_opts
      |> Map.new()
      |> maybe_alert(alert)

    notification.custom_data
    |> Map.new()
    |> Map.put("aps", aps_opts)
  end

  @doc """
  Function providing `Sparrow.H2Worker.Authentication.TokenBased` for APNS workers.
  Requres `Sparrow.APNS.TokenBearer` to be started.
  """
  @spec get_token_based_authentication(atom) ::
          Sparrow.H2Worker.Authentication.TokenBased.t()
  def get_token_based_authentication(token_id) do
    getter = fn ->
      {"authorization",
       "bearer #{Sparrow.APNS.TokenBearer.get_token(token_id)}"}
    end

    Sparrow.H2Worker.Authentication.TokenBased.new(getter)
  end

  @doc """
  Function providing `Sparrow.H2Worker.Authentication.CertificateBased` for APNS workers.

  ##Arguments

    * `path_to_cert` - path to APNS certificate file
    * `path_to_key` - path to APNS key file
  """
  @spec get_certificate_based_authentication(Path.t(), Path.t()) ::
          Sparrow.H2Worker.Authentication.CertificateBased.t()
  def get_certificate_based_authentication(path_to_cert, path_to_key) do
    Sparrow.H2Worker.Authentication.CertificateBased.new(
      path_to_cert,
      path_to_key
    )
  end

  @doc """
  Function providing `Sparrow.H2Worker.Config` for APNS workers.

  ## Example

  # Token based authentication:
    config =
      Sparrow.APNS.get_token_based_authentication()
      |> Sparrow.APNS.get_h2worker_config_dev()

  # Certificate based authentication:
    config =
      "path/to/certificate"
      |> Sparrow.APNS.get_certificate_based_authentication("path/to/key")
      |> Sparrow.APNS.get_h2worker_config_dev()

  """
  @spec get_h2worker_config_prod(
          authentication,
          String.t(),
          pos_integer,
          tls_options,
          time_in_miliseconds,
          pos_integer
        ) :: Sparrow.H2Worker.Config.t()
  def get_h2worker_config_prod(
        authentication,
        uri \\ "api.push.apple.com",
        port \\ 443,
        tls_opts \\ [],
        ping_interval \\ 5000,
        reconnect_attempts \\ 3
      ) do
    Sparrow.H2Worker.Config.new(%{
      domain: uri,
      port: port,
      authentication: authentication,
      tls_options: tls_opts,
      ping_interval: ping_interval,
      reconnect_attempts: reconnect_attempts
    })
  end

  @doc """
  Function providing `Sparrow.H2Worker.Config` for APNS workers.
  """
  @spec get_h2worker_config_dev(
          authentication,
          String.t(),
          pos_integer,
          tls_options,
          time_in_miliseconds,
          pos_integer
        ) :: Sparrow.H2Worker.Config.t()
  def get_h2worker_config_dev(
        authentication,
        uri \\ "api.development.push.apple.com",
        port \\ 443,
        tls_opts \\ [],
        ping_interval \\ 5000,
        reconnect_attempts \\ 3
      ) do
    Sparrow.H2Worker.Config.new(%{
      domain: uri,
      port: port,
      authentication: authentication,
      tls_options: tls_opts,
      ping_interval: ping_interval,
      reconnect_attempts: reconnect_attempts
    })
  end

  @spec notification_contains_title_or_body?(Sparrow.APNS.Notification.t()) ::
          boolean()
  defp notification_contains_title_or_body?(notification) do
    to_boolean = fn
      false -> false
      _ -> true
    end

    contains_title =
      notification.alert_opts |> Keyword.get(:title, false) |> to_boolean.()

    contains_body =
      notification.alert_opts |> Keyword.get(:body, false) |> to_boolean.()

    contains_title or contains_body
  end

  @spec get_reason_from_body(String.t()) :: String.t() | nil
  defp get_reason_from_body(body) do
    body |> Jason.decode!() |> Map.get("reason")
  end

  defp maybe_alert(map, alert) do
    case Map.keys(alert) do
      [] -> map
      _ -> Map.put(map, "alert", alert)
    end
  end
end
