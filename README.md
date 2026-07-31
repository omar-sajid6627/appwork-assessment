# AppworkCache

A concurrent, in-memory LRU + TTL cache written in Elixir, built for AppWork's take-home
technical exercise. It wraps a "slow" upstream service behind an identical `fetch(request) ->
response` interface, serving repeat requests from cache instead of forwarding them upstream.

The full exercise spec is in [`docs/appwork.md`](docs/appwork.md) (transcribed from
`docs/appwork.pdf`). The design rationale and diagrams live in
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Requirements coverage

The implementation is built progressively, matching the exercise's V0-V4 structure. Each version
is its own commit (or small commit sequence) so the git history documents the process:

| Version | What it adds | Status |
| --- | --- | --- |
| V0 | Cache interface: behaviours/protocols | done |
| V1 | Capped-capacity cache | done |
| V2 | True LRU (distinct entries, recency-ordered) | done |
| V3 | LRU + TTL | done |
| V4 | Amortized O(1) fetch | documented design only (see `ARCHITECTURE.md`), not implemented |

## Running it

```sh
mix deps.get
mix test
```

Static analysis:

```sh
mix format --check-formatted
mix credo
mix dialyzer   # first run builds a PLT and takes a few minutes
```

## Project layout

- `lib/appwork_cache/cache.ex` — the `Cache` behaviour (public contract).
- `lib/appwork_cache/upstream.ex` — the `Upstream` behaviour the cache wraps.
- `lib/appwork_cache/cacheable.ex` — `Cacheable` protocol (request hashing).
- `lib/appwork_cache/expirable.ex` — `Expirable` protocol (response TTL).
- `lib/appwork_cache/clock.ex` / `lib/appwork_cache/clock/system.ex` — `Clock` behaviour
  (injectable time source for TTL) and its real-clock implementation.
- `lib/appwork_cache/lru_cache.ex` — the `GenServer`-backed cache implementation.
- `test/support/` — example `Request`/`Response` structs and fake `Upstream`/`Clock` test doubles.

## Git history

Each version is its own commit, in order:

```
Scaffold Mix project and bring in exercise spec
V0: define the cache interface
V1: capped-capacity cache
V2: true LRU (recency-based eviction)
V3: LRU + TTL
```

Commit messages explain the *why* behind each version's change, not just the diff - in
particular, the concurrency design (`fetch/2` as a two-phase, client-driven flow) is introduced
and justified in the V1 commit and holds unchanged through V2/V3.
