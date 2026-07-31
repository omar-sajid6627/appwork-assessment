defprotocol AppworkCache.Cacheable do
  @moduledoc """
  Implemented by request structs so a cache can key entries without knowing
  the concrete request type.

  `hash/1` only needs to be a *nearly unique* integer (per the exercise's own
  assumption) — cheap equality/lookup matters more than perfect uniqueness.
  """

  @doc "Returns a nearly unique integer hash for a request."
  @spec hash(t) :: integer()
  def hash(request)
end
