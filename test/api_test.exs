defmodule Sparrow.APITest do
  use ExUnit.Case

  import Mock

  alias Helpers.SetupHelper, as: Setup

  @tags [:alpha, :beta, :gamma]

  test "FCM notification is send correctly" do
    with_mock Sparrow.FCM.V1,
      push: fn _, _, _ -> :ok end,
      process_response: fn _ -> :ok end do
      pool = start_pool(:fcm, @tags)
      notification = fcm_notification()

      assert :ok == Sparrow.API.push(notification, [:alpha])
      assert called(Sparrow.FCM.V1.push(pool, notification, []))
    end
  end

  test "APNS notification is send correctly" do
    with_mock Sparrow.APNS,
      push: fn _, _, _ -> :ok end,
      push: fn _, _ -> :ok end,
      process_response: fn _ -> :ok end do
      pool = start_pool({:apns, :dev}, @tags)
      notification = apns_notification()

      assert :ok == Sparrow.API.push(notification, [:alpha])
      assert called(Sparrow.APNS.push(pool, notification, []))
    end
  end

  test "async notification is send" do
    with_mock Sparrow.APNS,
      push: fn _, _, _ -> :ok end,
      push: fn _, _ -> :ok end,
      process_response: fn _ -> :ok end do
      pool = start_pool({:apns, :dev}, @tags)
      notification = apns_notification()

      assert :ok == Sparrow.API.push_async(notification, [:alpha])
      assert called(Sparrow.APNS.push(pool, notification, [{:is_sync, false}]))
    end
  end

  test "APNS pool not found" do
    start_pool({:apns, :dev}, @tags)

    assert {:error, :configuration_error} ==
             Sparrow.API.push(apns_notification(), [:delta])
  end

  test "FCM pool not found" do
    start_pool(:fcm, @tags)

    assert {:error, :configuration_error} ==
             Sparrow.API.push(fcm_notification(), [:delta])
  end

  test "sending APNS and FCM notifications to pools with the same tags" do
    with_mocks([
      {Sparrow.FCM.V1, [:passthrough],
       [
         push: fn _, _, _ -> :ok end,
         process_response: fn _ -> :ok end
       ]},
      {Sparrow.APNS, [:passthrough],
       [
         push: fn _, _, _ -> :ok end,
         push: fn _, _ -> :ok end,
         process_response: fn _ -> :ok end
       ]}
    ]) do
      apns_pool = start_pool({:apns, :dev}, @tags)
      fcm_pool = start_pool(:fcm, @tags)
      apns_notification = apns_notification()
      fcm_notification = fcm_notification()

      assert :ok == Sparrow.API.push(apns_notification, @tags)
      assert :ok == Sparrow.API.push(fcm_notification, @tags)

      assert called(Sparrow.APNS.push(apns_pool, apns_notification, []))
      assert called(Sparrow.FCM.V1.push(fcm_pool, fcm_notification, []))
    end
  end

  # Nothing listens on this port, the pools are only registered
  defp start_pool(type, tags) do
    config = Setup.create_pool_config(Setup.server_host(), 1, :token_based)
    {:ok, _pid} = Setup.start_pool(config, type: type, tags: tags)
    config.name
  end

  defp apns_notification do
    "dummy token"
    |> Sparrow.APNS.Notification.new(:dev)
    |> Sparrow.APNS.Notification.add_title("title")
    |> Sparrow.APNS.Notification.add_body("body")
  end

  defp fcm_notification do
    android_notification =
      Sparrow.FCM.V1.Android.new()
      |> Sparrow.FCM.V1.Android.add_title("title")
      |> Sparrow.FCM.V1.Android.add_body("body")

    :topic
    |> Sparrow.FCM.V1.Notification.new("news")
    |> Sparrow.FCM.V1.Notification.add_android(android_notification)
  end
end
