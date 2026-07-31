defmodule AppworkCache.Clock do
  @moduledoc """
  An injectable time source for TTL expiry.

  Letting the cache take a `Clock` module (defaulting to
  `AppworkCache.Clock.System`) instead of calling `System.monotonic_time/1`
  directly means TTL behavior can be tested deterministically - advancing a
  fake clock - rather than relying on real elapsed time via
  `Process.sleep/1`.
  """

  @doc "Returns the current time, in whole seconds, on a monotonically increasing scale."
  @callback monotonic_time() :: integer()
end
