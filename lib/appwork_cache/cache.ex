defmodule AppworkCache.Cache do
  @moduledoc """
  The public contract a cache implementation exposes to callers.

  A cache mirrors the interface of the `AppworkCache.Upstream` it wraps
  (`fetch(request) -> response`), plus a way to start an instance. Callers
  should be able to swap a cache in front of an upstream without changing how
  they call `fetch/2`.
  """

  @doc "Starts a cache process."
  @callback start_link(opts :: keyword()) :: GenServer.on_start()

  @doc """
  Returns the response for `request`, serving it from cache when possible and
  falling back to the wrapped upstream otherwise.
  """
  @callback fetch(cache :: GenServer.server(), request :: struct()) :: struct()
end
