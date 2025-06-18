defmodule StreamingDelta.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/michaelbearne/streaming_delta"

  def project do
    [
      app: :streaming_delta,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:delta, "~> 0.4.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Streaming parser that transforms an LLM's markdown output into a Delta."
  end

  # https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html#module-package-configuration
  defp package do
    [
      name: "streaming_delta",
      maintainers: ["Michael Bearne"],
      links: %{"GitHub" => @source_url},
      licenses: ["MIT"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
