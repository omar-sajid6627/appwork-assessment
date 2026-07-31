defmodule AppworkCache.LRUCache do
  @moduledoc """
  A `GenServer`-backed cache that wraps an `AppworkCache.Upstream`, keeping
  the `:cap` most recently used distinct requests: a hit moves its entry to
  most-recently-used, and once more than `:cap` distinct entries are stored,
  the least-recently-used one is evicted.

  `fetch/2` is deliberately a two-phase, client-driven flow instead of doing
  everything inside a single `GenServer.call`:

    1. Ask the cache process whether it already has a valid entry.
    2. On a miss, the *calling process* (not the cache process) calls the
       slow upstream directly.
    3. The calling process reports the result back to the cache process to
       store.

  This keeps the (potentially slow) upstream call off the cache process's
  mailbox, so one caller's cache miss never blocks other concurrent
  `fetch/2` callers - whether they're hits or misses on different keys. The
  tradeoff: two concurrent misses on the *same* key can both call upstream;
  this cache does not deduplicate in-flight fetches.

  Recency is tracked with a plain MRU-first list (`touch/2` does a
  `List.delete/2` + prepend, eviction pops the tail) rather than a proper
  O(1) structure. That's an intentional simplicity-over-optimization choice
  for a `:cap`-bounded cache; see `ARCHITECTURE.md` for the O(1) design this
  would become if amortized-O(1) fetch (the exercise's optional V4) were
  implemented.

  Entries also carry a TTL (via `AppworkCache.Expirable`, read from the
  response at insert time): a lookup that finds an entry whose TTL has
  elapsed is treated exactly like a miss, and is not counted as a "touch".
  Expiry is checked lazily, on lookup, against an injectable
  `AppworkCache.Clock` (defaulting to `AppworkCache.Clock.System`) rather
  than a background sweep - there's no correctness reason to evict an
  expired entry before anyone asks for it again, and `:cap` already bounds
  memory use independent of TTL.
  """

  use GenServer

  @behaviour AppworkCache.Cache

  alias AppworkCache.{Cacheable, Expirable}

  @type entry :: {response :: struct(), expires_at :: integer()}

  @type state :: %{
          cap: pos_integer(),
          upstream: module(),
          clock: module(),
          entries: %{integer() => entry()},
          order: [integer()]
        }

  @impl AppworkCache.Cache
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    cap = Keyword.fetch!(opts, :cap)
    upstream = Keyword.fetch!(opts, :upstream)
    clock = Keyword.get(opts, :clock, AppworkCache.Clock.System)

    unless is_integer(cap) and cap > 0 do
      raise ArgumentError, "cap must be a positive integer, got: #{inspect(cap)}"
    end

    gen_opts = Keyword.take(opts, [:name])
    GenServer.start_link(__MODULE__, %{cap: cap, upstream: upstream, clock: clock}, gen_opts)
  end

  @impl AppworkCache.Cache
  @spec fetch(GenServer.server(), struct()) :: struct()
  def fetch(cache, request) do
    hash = Cacheable.hash(request)

    case GenServer.call(cache, {:lookup, hash}) do
      {:hit, response} ->
        response

      {:miss, upstream} ->
        response = upstream.fetch(request)
        GenServer.call(cache, {:put, hash, response})
        response
    end
  end

  @impl GenServer
  def init(%{cap: cap, upstream: upstream, clock: clock}) do
    {:ok, %{cap: cap, upstream: upstream, clock: clock, entries: %{}, order: []}}
  end

  @impl GenServer
  def handle_call({:lookup, hash}, _from, state) do
    with {:ok, {response, expires_at}} <- Map.fetch(state.entries, hash),
         true <- expires_at > state.clock.monotonic_time() do
      {:reply, {:hit, response}, touch(state, hash)}
    else
      _not_found_or_expired -> {:reply, {:miss, state.upstream}, state}
    end
  end

  def handle_call({:put, hash, response}, _from, state) do
    expires_at = state.clock.monotonic_time() + Expirable.ttl(response)
    {:reply, :ok, put(state, hash, response, expires_at)}
  end

  @spec put(state(), integer(), struct(), integer()) :: state()
  defp put(state, hash, response, expires_at) do
    if Map.has_key?(state.entries, hash) do
      %{state | entries: Map.put(state.entries, hash, {response, expires_at})} |> touch(hash)
    else
      insert_new(state, hash, response, expires_at)
    end
  end

  @spec touch(state(), integer()) :: state()
  defp touch(state, hash) do
    %{state | order: [hash | List.delete(state.order, hash)]}
  end

  @spec insert_new(state(), integer(), struct(), integer()) :: state()
  defp insert_new(state, hash, response, expires_at) do
    state =
      %{state | entries: Map.put(state.entries, hash, {response, expires_at})} |> touch(hash)

    {entries, order} = evict_if_over_cap(state.entries, state.order, state.cap)
    %{state | entries: entries, order: order}
  end

  defp evict_if_over_cap(entries, order, cap) when map_size(entries) > cap do
    {oldest, order} = List.pop_at(order, -1)
    {Map.delete(entries, oldest), order}
  end

  defp evict_if_over_cap(entries, order, _cap), do: {entries, order}
end
