defmodule Support.Request do
  @moduledoc "Minimal request struct used across the test suite."

  @enforce_keys [:id]
  defstruct [:id]
end

defimpl AppworkCache.Cacheable, for: Support.Request do
  def hash(%Support.Request{} = request), do: :erlang.phash2(request)
end
