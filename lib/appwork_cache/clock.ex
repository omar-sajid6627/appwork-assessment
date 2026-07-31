defmodule AppworkCache.Clock do
  @moduledoc """
  An injectable time source for TTL expiry.

  Letting the cache take a `Clock` module (defaulting to
  `AppworkCache.Clock.System`) instead of calling `System.monotonic_time/1`
  directly means TTL behavior can be tested deterministically - advancing a
  fake clock - rather than relying on real elapsed time via
  `Process.sleep/1`.

  Time is in milliseconds even though TTLs are whole seconds: with a
  seconds-resolution clock, an entry stored at 0.999s with a 1s TTL would
  expire at 1.000s, after 1ms instead of 1s.
  """

  @doc "Returns the current time, in milliseconds, on a monotonically increasing scale."
  @callback monotonic_time() :: integer()
end
