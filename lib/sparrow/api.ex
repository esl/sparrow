defmodule Sparrow.API do
  @moduledoc """
  Sparrow main API.
  """
  require Logger

  @type notification ::
          Sparrow.FCM.V1.Notification.t() | Sparrow.APNS.Notification.t()
  @type sync_push_result ::
          Sparrow.FCM.V1.sync_push_result() | Sparrow.APNS.sync_push_result()
  @type pool_type :: Sparrow.PoolsWarden.pool_type()

  @doc """
  Function to FCM and APNS push notifications. Pushes notifcation and waits for response.

  ## Arguments

    * `notification` - is `Sparrow.APNS.Notification` or `Sparrow.FCM.V1.Notification` struct
    * `tags` - tags allow to determine which `Sparrow.H2Worker.Pool` is chosen to push notification.
    Pool type must be the same as notification type (`:fcm` or `{:apns, :dev}` or `{:apns, :prod}`).
    Pool is chosen as first found from collection of pools that have ale tags included.
    * `opts` -
        * `:timeout` - works only if `:is_sync` is `true`, after set `:timeout` miliseconds request is timeouted
        * `:strategy` - strategy of choosing worker in pool strategy
  """
  @spec push(notification, [any], Keyword.t()) ::
          :ok | sync_push_result | {:error, :configuration_error}
  def push(notification, tags \\ [], opts \\ []) do
    pool_type = get_pool_type(notification)

    case Sparrow.PoolsWarden.choose_pool(pool_type, tags) do
      nil ->
        _ =
          Logger.error(
            "worker=main_api, problem=no_tags_matching_pool_found, pool_type=#{
              inspect(pool_type)
            }, tags=#{inspect(tags)}"
          )

        {:error, :configuration_error}

      pool ->
        do_push(pool, notification, opts)
    end
  end

  @doc """
  Function to FCM and APNS push notifications. Pushes notifcation and returns `:ok` without waiting for response.

  ## Arguments

      * `notification` - is `Sparrow.APNS.Notification` or `Sparrow.FCM.V1.Notification` struct
      * `tags` - tags allow to determine which `Sparrow.H2Worker.Pool` is chosen to push notification.
        Pool type must be the same as notification type (`:fcm` or `{:apns, :dev}` or `{:apns, :prod}`).
        Pool is chosen as first found from collection of pools that have ale tags included.
      * `opts` -
          * `:strategy` - strategy of choosing worker in pool strategy
  """
  @spec push_async(notification, [any], Keyword.t()) ::
          :ok | {:error, :configuration_error}
  def push_async(notification, tags \\ [], opts \\ []) do
    push(notification, tags, [{:is_sync, false} | opts])
  end

  @spec get_pool_type(notification) :: pool_type
  defp get_pool_type(notification = %Sparrow.APNS.Notification{}) do
    {:apns, notification.type}
  end

  defp get_pool_type(_notification = %Sparrow.FCM.V1.Notification{}) do
    :fcm
  end

  @spec do_push(pool_name :: atom, notification, Keyword.t()) ::
          sync_push_result | :ok
  defp do_push(pool_name, notification = %Sparrow.APNS.Notification{}, opts) do
    Sparrow.APNS.push(pool_name, notification, opts)
  end

  defp do_push(pool_name, notification = %Sparrow.FCM.V1.Notification{}, opts) do
    project_id = Sparrow.FCM.V1.ProjectIdBearer.get_project_id(pool_name)

    notification =
      Sparrow.FCM.V1.Notification.add_project_id(notification, project_id)

    Sparrow.FCM.V1.push(pool_name, notification, opts)
  end
end
