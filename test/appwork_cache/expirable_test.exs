defmodule AppworkCache.ExpirableTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Expirable

  test "returns the response's configured TTL" do
    assert Expirable.ttl(%Support.Response{value: :x, ttl: 42}) == 42
  end

  test "ttl is a positive integer" do
    assert is_integer(Expirable.ttl(%Support.Response{value: :x}))
  end
end
