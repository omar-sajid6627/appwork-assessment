defmodule AppworkCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :appwork_cache,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # The Cacheable/Expirable protocols ship with no concrete implementation in
  # lib/ - real callers provide their own request/response structs. In :dev
  # that leaves the protocols with zero known implementations, which the
  # compiler (rightly) warns about at every call site. test/support's example
  # structs double as the reference implementation, so :dev compiles them too
  # (matching Elixir's own suggested fix); :prod stays lib/-only.
  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # The cache is a library: callers start LRUCache under their own
  # supervision tree, so there is no application callback module.
  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
