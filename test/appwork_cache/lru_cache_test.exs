defmodule AppworkCache.LRUCacheTest do
  use ExUnit.Case, async: false

  alias AppworkCache.LRUCache

  test "a cache miss calls upstream and stores the result" do
    start_supervised!(Support.Upstream)
    cache = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream})
    request = %Support.Request{id: 1}

    response = LRUCache.fetch(cache, request)

    assert response == %Support.Response{value: {:response_for, 1}}
    assert Support.Upstream.call_count() == 1
  end

  test "a repeated request within the last CAP requests is served from cache" do
    start_supervised!(Support.Upstream)
    cache = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream})
    request = %Support.Request{id: 1}

    response = LRUCache.fetch(cache, request)

    assert LRUCache.fetch(cache, request) == response
    assert LRUCache.fetch(cache, request) == response
    assert Support.Upstream.call_count() == 1
  end

  test "evicts the oldest inserted entry once more than CAP distinct requests arrive" do
    start_supervised!(Support.Upstream)
    cache = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream})
    r1 = %Support.Request{id: 1}
    r2 = %Support.Request{id: 2}
    r3 = %Support.Request{id: 3}

    LRUCache.fetch(cache, r1)
    LRUCache.fetch(cache, r2)
    LRUCache.fetch(cache, r3)
    assert Support.Upstream.call_count() == 3

    # r1 was the oldest inserted and is now evicted, so it must be refetched -
    # which is itself a new insertion that evicts r2, the next-oldest.
    LRUCache.fetch(cache, r1)
    assert Support.Upstream.call_count(r1) == 2

    # r3 was never evicted and is still served from cache.
    LRUCache.fetch(cache, r3)
    assert Support.Upstream.call_count(r3) == 1

    # r2, having just been evicted, must be refetched too.
    LRUCache.fetch(cache, r2)
    assert Support.Upstream.call_count(r2) == 2
  end

  test "touching an entry protects it from eviction, ahead of untouched entries" do
    start_supervised!(Support.Upstream)
    cache = start_supervised!({LRUCache, cap: 2, upstream: Support.Upstream})
    r1 = %Support.Request{id: 1}
    r2 = %Support.Request{id: 2}
    r3 = %Support.Request{id: 3}

    LRUCache.fetch(cache, r1)
    LRUCache.fetch(cache, r2)
    # Touching r1 (a hit) makes it the most-recently-used, ahead of r2.
    LRUCache.fetch(cache, r1)
    assert Support.Upstream.call_count(r1) == 1

    # Inserting a third distinct request evicts the least-recently-used
    # entry, which is now r2 (untouched since its insertion) - not r1.
    LRUCache.fetch(cache, r3)

    LRUCache.fetch(cache, r1)
    assert Support.Upstream.call_count(r1) == 1

    LRUCache.fetch(cache, r2)
    assert Support.Upstream.call_count(r2) == 2
  end

  test "start_link rejects a non-positive-integer cap" do
    assert_raise ArgumentError, fn ->
      LRUCache.start_link(cap: 0, upstream: Support.Upstream)
    end
  end

  test "concurrent fetches to different keys don't serialize behind a slow upstream" do
    start_supervised!({Support.Upstream, delay_ms: 50})
    cache = start_supervised!({LRUCache, cap: 10, upstream: Support.Upstream})

    requests = for id <- 1..10, do: %Support.Request{id: id}

    {elapsed_us, results} =
      :timer.tc(fn ->
        requests
        |> Enum.map(&Task.async(fn -> LRUCache.fetch(cache, &1) end))
        |> Enum.map(&Task.await/1)
      end)

    assert length(results) == 10
    assert Enum.all?(results, &match?(%Support.Response{}, &1))
    # Ten 50ms upstream calls running one-at-a-time behind the cache process
    # would take >= 500ms; running concurrently should comfortably clear
    # well under that.
    assert elapsed_us < 300_000
  end

  test "concurrent misses on the same key may each call upstream (no single-flight dedup, by design)" do
    start_supervised!({Support.Upstream, delay_ms: 30})
    cache = start_supervised!({LRUCache, cap: 10, upstream: Support.Upstream})
    request = %Support.Request{id: 1}

    results =
      1..5
      |> Enum.map(fn _ -> Task.async(fn -> LRUCache.fetch(cache, request) end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.all?(results, &(&1 == List.first(results)))
    assert Support.Upstream.call_count(request) >= 1
  end
end
