defmodule Support.FakeClock do
  @moduledoc """
  A controllable `AppworkCache.Clock` for deterministic TTL tests: starts at
  `:start_at` milliseconds (default `0`) and only advances when `advance/1`
  or `advance_ms/1` is called, avoiding flaky, slow `Process.sleep/1`-based
  tests.
  """

  @behaviour AppworkCache.Clock

  use Agent

  def start_link(opts \\ []) do
    start_at = Keyword.get(opts, :start_at, 0)
    Agent.start_link(fn -> start_at end, name: __MODULE__)
  end

  @impl AppworkCache.Clock
  def monotonic_time, do: Agent.get(__MODULE__, & &1)

  @doc "Advances the fake clock by `seconds`."
  def advance(seconds), do: advance_ms(seconds * 1000)

  @doc "Advances the fake clock by `ms` milliseconds."
  def advance_ms(ms), do: Agent.update(__MODULE__, &(&1 + ms))
end
