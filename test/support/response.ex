defmodule Support.Response do
  @moduledoc "Minimal response struct used across the test suite."

  @enforce_keys [:value]
  defstruct value: nil, ttl: 3600
end

defimpl AppworkCache.Expirable, for: Support.Response do
  def ttl(%Support.Response{ttl: ttl}), do: ttl
end
