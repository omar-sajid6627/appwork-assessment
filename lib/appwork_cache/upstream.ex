defmodule AppworkCache.Upstream do
  @moduledoc """
  The "slow" internal service a cache wraps.

  A cache implementation calls a module implementing this behaviour only when
  it has no valid stored response for a given request.
  """

  @doc "Fetches the response for a request directly from the upstream service."
  @callback fetch(request :: struct()) :: struct()
end
