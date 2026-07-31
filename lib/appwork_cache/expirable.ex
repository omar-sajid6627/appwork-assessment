defprotocol AppworkCache.Expirable do
  @moduledoc """
  Implemented by response structs so a cache can determine how long a
  cached response stays valid, without knowing the concrete response type.
  """

  @doc "Returns how many seconds a response stays valid for, once cached."
  @spec ttl(t) :: pos_integer()
  def ttl(response)
end
