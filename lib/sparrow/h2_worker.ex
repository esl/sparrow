defmodule Sparrow.H2Worker do
  @moduledoc false
  # Sends requests through connections of a pool, see `Sparrow.H2Worker.Pool`.

  require Logger

  alias Sparrow.H2ClientAdapter
  alias Sparrow.H2Worker.Config

  @type config :: Sparrow.H2Worker.Config.t()
  @type connection_ref :: Sparrow.H2ClientAdapter.connection_ref()
  @type reason :: any
  @type request :: Sparrow.H2Worker.Request.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type response :: {:ok, {headers, body}} | {:error, reason}

  # Time to wait before sending again a request which was not sent
  @retry_delay 25

  @doc """
  Sends the request and waits for the response, for at most the timeout
  of the request. A request which was not sent is sent again until then.
  """
  @spec send_request(connection_ref, config, request) :: response
  def send_request(connection_ref, config, request) do
    started_at = System.monotonic_time(:microsecond)
    deadline = now() + request.timeout

    response =
      try do
        headers = request_headers(request, config)
        send_with_retry(request, headers, connection_ref, deadline)
      catch
        # The caller gets a response no matter what
        kind, reason -> {:error, {kind, reason}}
      end

    time = System.monotonic_time(:microsecond) - started_at
    report(response, time, config)
    response
  end

  @spec send_with_retry(request, headers, connection_ref, integer) :: response
  defp send_with_retry(request, headers, connection_ref, deadline) do
    time_left = deadline - now()

    case H2ClientAdapter.request(
           connection_ref,
           request.path,
           headers,
           request.body,
           max(time_left, 0)
         ) do
      {:retry, reason} when time_left > @retry_delay ->
        _ =
          Logger.debug("H2 request not sent, retrying",
            what: :h2_request_retry,
            reason: inspect(reason),
            time_left: time_left
          )

        Process.sleep(@retry_delay)
        send_with_retry(request, headers, connection_ref, deadline)

      {:retry, reason} ->
        {:error, reason}

      response ->
        response
    end
  end

  @spec request_headers(request, config) :: headers
  defp request_headers(request, config) do
    case Config.get_authentication_type(config) do
      :certificate_based ->
        request.headers

      :token_based ->
        [config.authentication.token_getter.() | request.headers]
    end
  end

  defp report(response, time, config) do
    pool_info = Config.pool_info(config)

    :telemetry.execute(
      [:sparrow, :h2_worker, :handle],
      %{time: time},
      pool_info
    )

    case response do
      {:ok, _response} ->
        :telemetry.execute(
          [:sparrow, :h2_worker, :request_success],
          %{},
          pool_info
        )

      {:error, reason} ->
        _ =
          Logger.warning("H2 request failed",
            what: :h2_request_failed,
            status: :error,
            reason: inspect(reason)
          )

        :telemetry.execute(
          [:sparrow, :h2_worker, :request_error],
          %{},
          Map.put(pool_info, :return_code, reason)
        )
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
