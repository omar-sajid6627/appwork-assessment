defmodule AppworkCache.Clock.SystemTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Clock.System, as: SystemClock

  test "returns a non-decreasing integer" do
    first = SystemClock.monotonic_time()
    second = SystemClock.monotonic_time()

    assert is_integer(first)
    assert second >= first
  end

  test "ticks in milliseconds" do
    before = System.monotonic_time(:millisecond)
    now = SystemClock.monotonic_time()
    later = System.monotonic_time(:millisecond)

    assert before <= now and now <= later
  end
end
