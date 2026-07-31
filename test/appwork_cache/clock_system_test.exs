defmodule AppworkCache.Clock.SystemTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Clock.System, as: SystemClock

  test "returns a non-decreasing integer number of seconds" do
    first = SystemClock.monotonic_time()
    second = SystemClock.monotonic_time()

    assert is_integer(first)
    assert second >= first
  end
end
