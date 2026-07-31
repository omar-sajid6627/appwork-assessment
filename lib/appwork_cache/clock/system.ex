defmodule AppworkCache.Clock.System do
  @moduledoc "The real system clock: wraps `System.monotonic_time/1`."

  @behaviour AppworkCache.Clock

  @impl AppworkCache.Clock
  def monotonic_time, do: System.monotonic_time(:second)
end
