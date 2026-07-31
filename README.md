# AppworkCache

A concurrent, in-memory LRU + TTL cache for Elixir/OTP. It sits in front of a slow upstream
service and exposes the same `fetch(request) -> response` interface, so callers can put it in
front of an upstream without changing how they call it. Repeat requests are served from memory
until their entry is either pushed out by newer requests or its TTL runs out.

It was written for a progressive take-home exercise (V0 to V4). The brief is in
[`docs/appwork.md`](docs/appwork.md), and the design rationale and diagrams are in
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## What it does

| Version | Behaviour | Status |
| --- | --- | --- |
| V0 | `Cache` and `Upstream` behaviours, `Cacheable` and `Expirable` protocols | done |
| V1 | Capped capacity: `:cap`, a positive integer, set at start | done |
| V2 | True LRU over distinct requests: a hit moves the entry to most recently used | done |
| V3 | Per-response TTL in seconds: an expired entry is a miss and is refetched | done |
| V4 | Amortized O(1) fetch | design only, see `ARCHITECTURE.md` |

## Usage

Requests implement `AppworkCache.Cacheable` (a cheap integer hash), responses implement
`AppworkCache.Expirable` (TTL in whole seconds), and the upstream module implements
`AppworkCache.Upstream`:

```elixir
defimpl AppworkCache.Cacheable, for: MyApp.PriceRequest do
  def hash(request), do: :erlang.phash2(request)
end

defimpl AppworkCache.Expirable, for: MyApp.PriceResponse do
  def ttl(_response), do: 30
end

{:ok, _pid} =
  AppworkCache.LRUCache.start_link(cap: 1_000, upstream: MyApp.PriceService, name: MyApp.PriceCache)

AppworkCache.LRUCache.fetch(MyApp.PriceCache, %MyApp.PriceRequest{sku: "A-17"})
```

Options for `start_link/1`:

- `:cap` (required) is the number of distinct requests kept. Anything but a positive integer raises
  `ArgumentError`.
- `:upstream` (required) is the module whose `fetch/1` is called on a miss.
- `:clock` (optional) is an `AppworkCache.Clock` implementation, `AppworkCache.Clock.System` by
  default. Tests swap in a fake one.
- `:name` (optional) registers the process.

Here is a run against the test-support upstream (200 ms latency, 2 s TTL, `cap: 2`), captured in
the Docker image below:

```text
first fetch : %Support.Response{value: {:response_for, 1}, ttl: 2} in 205 ms
repeat fetch: %Support.Response{value: {:response_for, 1}, ttl: 2} in 0 ms
after TTL   : %Support.Response{value: {:response_for, 1}, ttl: 2} in 200 ms
upstream calls: 2
```

## Running it

The toolchain is pinned in `.tool-versions` (Erlang/OTP 29.1.2, Elixir 1.20.5). With Docker,
nothing needs to be installed locally:

```sh
docker run --rm -v "$PWD":/app -w /app elixir:1.20.5-otp-29 \
  sh -c 'mix local.hex --force && mix deps.get && mix check'
```

With a local toolchain (for example via asdf or mise):

```sh
mix deps.get
mix check      # format check, warnings-as-errors compile, credo --strict, tests
mix dialyzer   # the first run builds a PLT and takes a few minutes
```

`mix test` on its own runs just the ExUnit suite. TTL tests use a fake clock, so the suite
does not sleep through real TTLs.

## Design notes

- **Upstream calls happen in the caller, not in the cache process.** `fetch/2` asks the
  GenServer for a lookup, calls the upstream in the calling process on a miss, then hands the
  response back to be stored. A slow upstream therefore never blocks other callers, whether they
  hit or miss.
- **Bad responses fail one caller only.** The TTL is read and validated in the calling process
  too, so a response without an `Expirable` implementation or with a TTL that isn't a positive
  integer raises in that caller. The cache process and its other entries are unaffected, and the
  same holds when the upstream raises or the caller is killed mid-fetch.
- **TTL is checked lazily, in milliseconds.** Expiry is checked on lookup, with no sweeper
  process. `:cap` already bounds memory. The clock reports milliseconds, so a 1 s TTL lasts
  1 s and is not shortened by rounding to whole seconds.
- **Refreshing a key reuses its slot.** Refetching an expired entry updates it in place and makes
  it most recently used. It never evicts an unrelated entry to make room.

## Limitations

- Concurrent misses on the same key may each call the upstream: there is no single-flight
  deduplication.
- There is no upstream timeout. A caller waits as long as its upstream call takes, but other
  callers are not held up.
- Recency is a plain list, so each hit or insert costs O(`cap`). `ARCHITECTURE.md` describes
  the O(1) structure that V4 would use.

## Project layout

- `lib/appwork_cache/cache.ex` and `upstream.ex`: the `Cache` and `Upstream` behaviours.
- `lib/appwork_cache/cacheable.ex` and `expirable.ex`: the request and response protocols.
- `lib/appwork_cache/clock.ex` and `clock/system.ex`: the injectable millisecond clock.
- `lib/appwork_cache/lru_cache.ex`: the GenServer-backed cache.
- `test/support/`: example `Request`/`Response` structs plus fake `Upstream` and `Clock`. They
  are also compiled in `:dev`, where they serve as the reference protocol implementations.

## License

MIT, see [`LICENSE`](LICENSE).
