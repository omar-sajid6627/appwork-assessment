defmodule AppworkCache.CacheableTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Cacheable

  test "equal requests hash equal" do
    assert Cacheable.hash(%Support.Request{id: 1}) == Cacheable.hash(%Support.Request{id: 1})
  end

  test "different requests (almost always) hash differently" do
    refute Cacheable.hash(%Support.Request{id: 1}) == Cacheable.hash(%Support.Request{id: 2})
  end

  test "hash is an integer" do
    assert is_integer(Cacheable.hash(%Support.Request{id: :anything}))
  end
end
