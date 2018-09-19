defmodule Sparrow.APITest do
  use ExUnit.Case

  import Mock

  @body "{
    \"error\" : {
      \"code\" : 400,
      \"message\" : \"Request contains an invalid argument.\",
      \"status\" : \"INVALID_ARGUMENT\"
    }
  }"
  test "FCM notification is send correctly" do
    headers = [{"key1", "val1"}, {"key2", "val2"}, {":status", "400"}]
    body = "my test return body"

    with_mock Sparrow.FCM.V1,
      push: fn _, _, _ -> :ok end,
      push: fn _, _ -> :ok end,
      process_response: fn _ -> :ok end do
      Sparrow.PoolsWarden.start_link()

      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
          {"Authorization", "my_dummy_fcm_token"}
        end)

      pool_1_config =
        Sparrow.H2Worker.Config.new("fcm.googleapis.com", 443, auth)
        |> Sparrow.H2Worker.Pool.Config.new()

      pool_1_name = pool_1_config.pool_name

      {:ok, _pid} =
        Sparrow.H2Worker.Pool.start_link(pool_1_config, :fcm, [
          :alpha,
          :beta,
          :gamma
        ])

      android_notification =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("title")
        |> Sparrow.FCM.V1.Android.add_body("body")

      fcm_notification =
        Sparrow.FCM.V1.Notification.new(:topic, "news", "fake_id")
        |> Sparrow.FCM.V1.Notification.add_android(android_notification)

      assert :ok == Sparrow.API.push(fcm_notification, [:alpha])

      assert called Sparrow.FCM.V1.push(pool_1_name, fcm_notification, [])
    end
  end

  test "APNS notification is send correctly" do
    headers = [{"key1", "val1"}, {"key2", "val2"}, {":status", "200"}]
    body = "my test return body"

    with_mock Sparrow.APNS,
      push: fn _, _, _ -> :ok end,
      push: fn _, _ -> :ok end,
      process_response: fn _ -> :ok end do
      Sparrow.PoolsWarden.start_link()

      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
          {"Authorization", "my_dummy_fcm_token"}
        end)

      pool_1_config =
        Sparrow.H2Worker.Config.new("api.push.apple.com", 443, auth)
        |> Sparrow.H2Worker.Pool.Config.new()

      pool_1_name = pool_1_config.pool_name

      {:ok, _pid} =
        Sparrow.H2Worker.Pool.start_link(pool_1_config, {:apns, :dev}, [
          :alpha,
          :beta,
          :gamma
        ])

      apns_notification =
        Sparrow.APNS.Notification.new("dummy token", :dev)
        |> Sparrow.APNS.Notification.add_title("title")
        |> Sparrow.APNS.Notification.add_body("body")

      assert :ok == Sparrow.API.push(apns_notification, [:alpha])

      assert called Sparrow.APNS.push(pool_1_name, apns_notification, [])
    end
  end

  test "async notification is send" do
    headers = [{"key1", "val1"}, {":status", "400"}, {"key2", "val2"}]
    body = "my test return body"

    with_mock Sparrow.APNS,
      push: fn _, _, _ -> :ok end,
      push: fn _, _ -> :ok end,
      process_response: fn _ -> :ok end do
      Sparrow.PoolsWarden.start_link()

      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
          {"Authorization", "my_dummy_fcm_token"}
        end)

      pool_1_config =
        Sparrow.H2Worker.Config.new("api.push.apple.com", 443, auth)
        |> Sparrow.H2Worker.Pool.Config.new()

      pool_1_name = pool_1_config.pool_name

      {:ok, _pid} =
        Sparrow.H2Worker.Pool.start_link(pool_1_config, {:apns, :dev}, [
          :alpha,
          :beta,
          :gamma
        ])

      apns_notification =
        Sparrow.APNS.Notification.new("dummy token", :dev)
        |> Sparrow.APNS.Notification.add_title("title")
        |> Sparrow.APNS.Notification.add_body("body")

      assert :ok == Sparrow.API.push_async(apns_notification, [:alpha])

      assert called Sparrow.APNS.push(pool_1_name, apns_notification, [
                      {:is_sync, false}
                    ])
    end
  end

  test "APNS pool not found" do
    with_mock Sparrow.PoolsWarden,
      choose_pool: fn _, _ -> nil end,
      add_new_pool: fn _, _, _ -> true end do
      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
          {"Authorization", "my_dummy_fcm_token"}
        end)

      pool_1_config =
        Sparrow.H2Worker.Config.new("api.push.apple.com", 443, auth)
        |> Sparrow.H2Worker.Pool.Config.new()

      {:ok, _pid} =
        Sparrow.H2Worker.Pool.start_link(pool_1_config, {:apns, :dev}, [
          :alpha,
          :beta,
          :gamma
        ])

      apns_notification =
        Sparrow.APNS.Notification.new("dummy token", :dev)
        |> Sparrow.APNS.Notification.add_title("title")
        |> Sparrow.APNS.Notification.add_body("body")

      assert {:error, :configuration_error} ==
               Sparrow.API.push(apns_notification, [:delta])
    end
  end

  test "FCM pool not found" do
    with_mock Sparrow.PoolsWarden,
      choose_pool: fn _, _ -> nil end,
      add_new_pool: fn _, _, _ -> true end do
      auth =
        Sparrow.H2Worker.Authentication.TokenBased.new(fn ->
          {"Authorization", "my_dummy_fcm_token"}
        end)

      pool_1_config =
        Sparrow.H2Worker.Config.new("fcm.googleapis.com", 443, auth)
        |> Sparrow.H2Worker.Pool.Config.new()

      {:ok, _pid} =
        Sparrow.H2Worker.Pool.start_link(pool_1_config, :fcm, [
          :alpha,
          :beta,
          :gamma
        ])

      android_notification =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("title")
        |> Sparrow.FCM.V1.Android.add_body("body")

      fcm_notification =
        Sparrow.FCM.V1.Notification.new(:topic, "news", "fake_id")
        |> Sparrow.FCM.V1.Notification.add_android(android_notification)

      assert {:error, :configuration_error} ==
               Sparrow.API.push(fcm_notification, [:alpha])
    end
  end
end
