defmodule Support.Upstream do
  @moduledoc """
  A fake `AppworkCache.Upstream` for tests: a named `Agent` that records
  every call it receives and can simulate latency, so tests can assert on
  call counts and exercise the cache's concurrency behavior.
  """

  @behaviour AppworkCache.Upstream

  use Agent

  @doc """
  Starts (or restarts) the fake upstream. `delay_ms` simulates upstream
  latency; `ttl` sets the TTL (in seconds) of every response it returns.
  Tests that don't care about either can omit them.
  """
  def start_link(opts \\ []) do
    delay_ms = Keyword.get(opts, :delay_ms, 0)
    ttl = Keyword.get(opts, :ttl, 3600)
    Agent.start_link(fn -> %{delay_ms: delay_ms, ttl: ttl, calls: []} end, name: __MODULE__)
  end

  @impl AppworkCache.Upstream
  def fetch(%Support.Request{} = request) do
    %{delay_ms: delay_ms, ttl: ttl} = Agent.get(__MODULE__, & &1)
    if delay_ms > 0, do: Process.sleep(delay_ms)
    Agent.update(__MODULE__, &Map.update!(&1, :calls, fn calls -> [request | calls] end))
    %Support.Response{value: {:response_for, request.id}, ttl: ttl}
  end

  @doc "Changes the TTL used for responses returned from now on."
  def set_ttl(ttl), do: Agent.update(__MODULE__, &Map.put(&1, :ttl, ttl))

  @doc "Requests the upstream has been called with, most recent first."
  def calls, do: Agent.get(__MODULE__, & &1.calls)

  @doc "How many times the upstream has been called, total or for one request."
  def call_count, do: length(calls())
  def call_count(%Support.Request{} = request), do: Enum.count(calls(), &(&1 == request))
end
