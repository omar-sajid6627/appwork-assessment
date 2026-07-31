# Elixir Technical Exercise

## LRU + TTL Cache in Elixir (Progressive Exercise)

This exercise is designed to evaluate your ability to write production-ready Elixir code under realistic development constraints.

### Timebox

Please allocate a fixed amount of time in advance. Recommended: **4 to 8 hours**. The exact time is up to you, as long as you plan in advance.

The requirements are progressive (V0 through V4). Implement as much as you can within the timebox. You are **not expected** to reach V4.

**Code quality comes first.** Optimization is a bonus. Neither specialization nor generalization are bonuses. Please advance to the next version only after the current version is stable wrt required functionality and production-grade wrt code quality.

You are encouraged to document your process, since you will be asked to discuss it during the review. Git commits should be sufficient for this purpose.

### Goal

Implement an efficient cache that:

- Uses **request structs** as keys and **response structs** as values.
- Supports **LRU + TTL eviction** (progressively introduced).
- Wraps an upstream internal service with an identical interface: `fetch(req) -> res`

### Overview and Assumptions

- Assume (and implement for testing) a function that returns a (*nearly unique*) **integer hash** for a request struct, or another efficient mechanism for comparing requests.
- The cache mechanism should call the "slow" upstream **only if** it does not have a valid stored response for the given request.
- Assume each response is **unique per request**.
- The cache must support **high concurrency**, allowing many concurrent fetch calls.

### Requirements

#### V0 - Cache Interface

Define a minimal interface for the cache mechanism (protocols and/or behaviours as appropriate).

#### V1 - Basic Cache (Capped Capacity)

- The cache receives **CAP** (a positive integer) at initialization.
- It must store responses for at least the last CAP requests.
- If a request appears again within the last CAP requests, it should be served from cache and **not** forwarded upstream.

#### V2 - LRU Cache

- Same as V1, with the added constraint that the stored entries are **distinct request-response tuples**.
- In other words: if the same request appears within the last CAP distinct requests, it should be served from cache.

#### V3 - LRU + TTL Cache

- Same as V2, with the additional constraint that responses have a **TTL**:
  - TTL is a positive integer number of seconds.
  - After TTL expires, the cached response is invalid and must be re-fetched from upstream.
- Assume (and implement for testing) a function on the response struct that returns its TTL (in other words: a request should be served from cache only if it is within the last CAP distinct requests **and** the cached response is still valid).

#### V4 - Near Real-Time LRU + TTL Cache

- Same as V3, with the added requirement that the "no-upstream" fetch operation achieves **amortized O(1)** end-to-end.
- Practically: in the vast majority of cases, under stable conditions, fetch should complete consistently within a predictable time bound.

### Deliverables

Please provide:

1. **Code submission**
   - A publicly accessible Git repository link, or a zip file containing the project.

2. **Architecture artifact**
   - A class/module diagram illustrating:
     - Cache logic
     - Data flow
     - High-level design

Good Luck!

AppWork Hiring Team
