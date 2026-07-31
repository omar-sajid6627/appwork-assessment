defmodule AppworkCache.LRUCacheFailureTest do
  use ExUnit.Case, async: false

  alias AppworkCache.LRUCache

  defmodule RaisingUpstream do
    @behaviour AppworkCache.Upstream

    @impl AppworkCache.Upstream
    def fetch(_request), do: raise("upstream unavailable")
  end

  defmodule BareResponse do
    defstruct [:value]
  end

  defmodule BareUpstream do
    @behaviour AppworkCache.Upstream

    @impl AppworkCache.Upstream
    def fetch(request), do: %BareResponse{value: request.id}
  end

  describe "upstream errors" do
    test "propagate to the caller and leave the cache serving other keys" do
      start_supervised!(Support.Upstream)
      healthy = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream}, id: :healthy)
      failing = start_supervised!({LRUCache, cap: 2, upstream: RaisingUpstream}, id: :failing)

      assert_raise RuntimeError, "upstream unavailable", fn ->
        LRUCache.fetch(failing, %Support.Request{id: 1})
      end

      assert Process.alive?(failing)
      assert %Support.Response{} = LRUCache.fetch(healthy, %Support.Request{id: 1})
    end

    test "a caller killed mid-fetch stores nothing, so the next caller refetches" do
      start_supervised!({Support.Upstream, delay_ms: 500})
      cache = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream})
      request = %Support.Request{id: 1}

      task = Task.async(fn -> LRUCache.fetch(cache, request) end)
      assert Task.yield(task, 20) == nil
      Task.shutdown(task, :brutal_kill)

      Support.Upstream.set_delay(0)
      assert LRUCache.fetch(cache, request) == %Support.Response{value: {:response_for, 1}}
      assert Support.Upstream.call_count(request) == 1
    end
  end

  describe "invalid TTLs" do
    for bad_ttl <- [0, -5, 1.5, nil] do
      test "a TTL of #{inspect(bad_ttl)} fails the caller, not the cache process" do
        start_supervised!({Support.Upstream, ttl: unquote(bad_ttl)})
        cache = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream})

        assert_raise ArgumentError, ~r/positive integer/, fn ->
          LRUCache.fetch(cache, %Support.Request{id: 1})
        end

        assert Process.alive?(cache)
        Support.Upstream.set_ttl(60)
        assert %Support.Response{} = LRUCache.fetch(cache, %Support.Request{id: 1})
      end
    end

    test "a response without an Expirable implementation fails the caller only" do
      cache = start_supervised!({LRUCache, cap: 2, upstream: BareUpstream})

      assert_raise Protocol.UndefinedError, fn ->
        LRUCache.fetch(cache, %Support.Request{id: 1})
      end

      assert Process.alive?(cache)
    end
  end
end
