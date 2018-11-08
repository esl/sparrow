defmodule Sparrow.APNS.Notification.Sound do
  @moduledoc """
  Helper to build sound dictionary for APNS notification.

  ## Example

    alias Sparrow.APNS.Notification.Sound
    sound =
      "chirp"
      |> Sound.new()
      |> Sound.add_critical()
      |> Sound.add_volume(0.07)
  """

  @doc """
  Method to create new sound.
  """
  @spec new(String.t()) :: map
  def new(name) do
    %{
      "name" => name
    }
  end

  @doc """
  The critical alert flag. Set to 1 to enable the critical alert.
  """
  @spec add_critical(map) :: map
  def add_critical(sound) do
    Map.put(sound, "critical", 1)
  end

  @doc """
    The volume for the critical alert’s sound. Set this to a value between 0.0 (silent) and 1.0 (full volume).
  """
  @spec add_volume(map, float) :: map
  def add_volume(sound, volume) do
    Map.put(sound, "volume", volume)
  end
end
