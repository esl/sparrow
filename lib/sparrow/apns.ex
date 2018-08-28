defmodule Sparrow.APNS do
  @moduledoc """
  Provides functions to build and send push notifications to APNS
  """
  require Logger

  alias Sparrow.H2Worker.Request

  @type reason :: any
  @type headers :: Request.headers()
  @type body :: String.t()
  @type state :: Sparrow.H2Worker.State.t()
  @type push_opts :: [{:is_sync, boolean()} | {:timeout, non_neg_integer}]
  @type http_status :: non_neg_integer
  @path "/3/device/"

  @doc """
  Sends the push notification to APNS.

  ## Options

  * `:is_sync` - Determines whether the worker should wait for response after sending the request. When set to `true` (default), the result of calling this functions is one of:
      * `{:ok, {headers, body}}` when the response is received. `headers` are the response headers and `body` is the response body.
      * `{:error, :request_timeout}` when the response doesn't arrive until timeout occurs (see the `:timeout` option).
      * `{:error, :connection_lost}` when the connection to APNS is lost before the response arrives.
      * `{:error, :not_ready}` when stream response is not yet ready, but it h2worker tries to get it.
      * `{:error, :invalid_notification}` when notification does not contain neither title nor body.
      * `{:error, :reason}` when error with other reason occures.
    * `:timeout` - Request timeout in milliseconds. Defaults value is 5000.

  ## Example

    # For more details on how to get device token and apns-topic go to project's ReadMe.
    @device_token "MYFAKEEXAMPLETOKENDEVICE"
    @apns_topic "MYFAKEEXAMPLEAPNSTOPIC"

    #start worker like in ReadMe
    auth = Sparrow.H2Worker.Authentication.CertificateBased.new("path/to/exampleName.pem","path/to/exampleKey.pem")
    config = Sparrow.H2Worker.Config.new("api.development.push.apple.com", 443, auth)
    {:ok, worker_pid} = Sparrow.H2Worker.start_link(:your_apns_workers_name, config)
    #create notification
    notification =
        Notification.new(@device_token)
        |> Notification.add_title("example title")
        |> Notification.add_body("example body")
        |> Notification.add_apns_topic(@apns_topic)

    Sparrow.APNS.push(worker_pid, notification)
  """
  @spec push(
          Sparrow.H2Worker.process(),
          Sparrow.APNS.Notification.t(),
          push_opts
        ) ::
          {:error, :connection_lost}
          | {:ok, {headers, body}}
          | {:error, :request_timeout}
          | {:error, :not_ready}
          | {:error, :invalid_notification}
          | {:error, reason}
          | :ok
  def push(h2_worker, notification, opts \\ []) do
    if notification_contains_title_or_body?(notification) do
      is_sync = Keyword.get(opts, :is_sync, true)
      timeout = Keyword.get(opts, :timeout, 5_000)
      path = @path <> notification.device_token
      headers = notification.headers
      json_body = notification |> make_body() |> Jason.encode!()
      request = Request.new(headers, json_body, path, timeout)

      _ =
        Logger.debug(fn ->
          "action=push_apns_notification, request=#{inspect(request)}"
        end)

      Sparrow.H2Worker.send_request(h2_worker, request, is_sync, timeout)
    else
      _ =
        Logger.warn(fn ->
          "Attempt to send notification without title and body"
        end)

      {:error, :invalid_notification}
    end
  end

  @doc """
  Parses the return value of `push/2` returning the status code and reason in case of errors
  You can combine it with `Sparrow.APNS.get_error_description/1` to get a human-readable description of the error reason.
  Note that this function is useful only if you push the notification in synchronous mode.

  ## Example

  push_result =
      worker
      |> Sparrow.APNS.push(notification)
      |> process_response()
  case push_result do
      :ok ->
          :ok
      {:error, {status, reason}} ->
          Sparrow.APNS.get_error_description(status, reason)
  end
  """
  @spec process_response({:ok, {headers, body}} | {:error, reason}) ::
          :ok
          | {:error,
             {status ::
                String.t()
                | nil, reason :: String.t() | nil}
             | reason :: :request_timeout | :not_ready | reason}
  def process_response({:ok, {headers, body}}) do
    if {":status", "200"} in headers do
      _ =
        Logger.debug(fn ->
          "action=handle_push_response, result=succes, status=200"
        end)

      :ok
    else
      status = get_status_from_headers(headers)
      reason = get_reason_from_body(body)

      _ =
        Logger.info(fn ->
          "action=handle_push_response, result=fail, status=#{inspect(status)}, reason=#{
            inspect(reason)
          }"
        end)

      {:error, {status, reason}}
    end
  end

  def process_response({:error, reason}), do: {:error, reason}

  @doc """
  Function provides APNS errors description.

  Further details:
  https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW1
  Table 8-6 Values for the APNs JSON reason key

  ## Arguments

    * `status_code` from http response :status header
    * `error_string` from http response json body key reason
  """
  @spec get_error_description(non_neg_integer, String.t()) :: String.t()
  def get_error_description(status, code) do
    Sparrow.APNS.Errors.get_error_description(status, code)
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
      |> Map.put("alert", alert)

    notification.custom_data
    |> Map.new()
    |> Map.put("aps", aps_opts)
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

  @spec get_status_from_headers(headers) :: nil | http_status
  defp get_status_from_headers(headers) do
    case List.keyfind(headers, ":status", 0) do
      {_, status} ->
        (fn ->
           {i, _} = Integer.parse(status)
           i
         end).()

      nil ->
        nil
    end
  end

  @spec get_reason_from_body(String.t()) :: String.t() | nil
  defp get_reason_from_body(body) do
    body |> Jason.decode!() |> Map.get("reason")
  end
end
