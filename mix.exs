defmodule PlugCaisson.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_caisson,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        extras: ~w[README.md],
        main: "readme",
        groups_for_modules: [
          Algorithms: [~R/PlugCaisson\./]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.15"},
      {:brotli, "~> 0.3.2", optional: true},
      {:ezstd, "~> 1.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: [:dev]}
    ]
  end
end
