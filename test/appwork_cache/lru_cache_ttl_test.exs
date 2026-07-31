defmodule AppworkCache.LRUCacheTTLTest do
  use ExUnit.Case, async: false

  alias AppworkCache.LRUCache

  setup do
    start_supervised!(Support.FakeClock)
    :ok
  end

  test "an entry within its TTL is served from cache" do
    start_supervised!({Support.Upstream, ttl: 10})
    cache = start_cache()
    request = %Support.Request{id: 1}

    LRUCache.fetch(cache, request)
    Support.FakeClock.advance(5)
    LRUCache.fetch(cache, request)

    assert Support.Upstream.call_count(request) == 1
  end

  test "an entry past its TTL is treated as a miss and refetched from upstream" do
    start_supervised!({Support.Upstream, ttl: 10})
    cache = start_cache()
    request = %Support.Request{id: 1}

    LRUCache.fetch(cache, request)
    Support.FakeClock.advance(10)
    LRUCache.fetch(cache, request)

    assert Support.Upstream.call_count(request) == 2
  end

  test "an entry is valid for its full TTL, measured in milliseconds" do
    stop_supervised!(Support.FakeClock)
    # Just before a whole-second boundary: a seconds-resolution clock would
    # round the insert time down and expire this entry after 1ms.
    start_supervised!({Support.FakeClock, start_at: 999})
    start_supervised!({Support.Upstream, ttl: 1})
    cache = start_cache()
    request = %Support.Request{id: 1}

    LRUCache.fetch(cache, request)
    Support.FakeClock.advance_ms(999)
    LRUCache.fetch(cache, request)
    assert Support.Upstream.call_count(request) == 1

    Support.FakeClock.advance_ms(1)
    LRUCache.fetch(cache, request)
    assert Support.Upstream.call_count(request) == 2
  end

  test "refreshing an expired entry doesn't evict other entries (no double-counting toward CAP)" do
    start_supervised!({Support.Upstream, ttl: 5})
    cache = start_cache()
    r1 = %Support.Request{id: 1}
    r2 = %Support.Request{id: 2}

    LRUCache.fetch(cache, r1)
    Support.Upstream.set_ttl(1000)
    LRUCache.fetch(cache, r2)

    Support.FakeClock.advance(5)

    # r1's TTL (5s) has elapsed; r2's (1000s) hasn't.
    LRUCache.fetch(cache, r1)
    assert Support.Upstream.call_count(r1) == 2

    # Refreshing r1 reused its existing slot instead of evicting r2 as if r1
    # were a brand new distinct request.
    LRUCache.fetch(cache, r2)
    assert Support.Upstream.call_count(r2) == 1
  end

  test "refetching an expired entry makes it the most recently used" do
    start_supervised!({Support.Upstream, ttl: 5})
    cache = start_cache()
    r1 = %Support.Request{id: 1}
    r2 = %Support.Request{id: 2}
    r3 = %Support.Request{id: 3}

    LRUCache.fetch(cache, r1)
    Support.Upstream.set_ttl(1000)
    LRUCache.fetch(cache, r2)
    Support.FakeClock.advance(5)

    # r1 expired and is refetched, which makes it the most recently used, so
    # the next new request evicts r2 rather than r1.
    LRUCache.fetch(cache, r1)
    LRUCache.fetch(cache, r3)

    LRUCache.fetch(cache, r1)
    assert Support.Upstream.call_count(r1) == 2
    LRUCache.fetch(cache, r2)
    assert Support.Upstream.call_count(r2) == 2
  end

  defp start_cache do
    start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream, clock: Support.FakeClock})
  end
end
