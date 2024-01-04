defmodule PlugCaisson.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_caisson,
      version: "0.1.2",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      test_coverage: [
        ignore_modules: [TestUtils]
      ],
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

  defp elixirc_paths(:test), do: ~w[lib test/support]
  defp elixirc_paths(_), do: ~w[lib]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.15"},
      {:brotli, "~> 0.3.2", optional: true},
      {:ezstd, "~> 1.0", optional: true},
      {:jason, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev]},
      {:credo, ">= 0.0.0", only: [:dev, :test]},
      {:stream_data, "~> 0.6.0", only: [:dev, :test]}
    ]
  end

  defp package() do
    [
      description: "Compressed Body Reader",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/supabase/plug_caisson"}
    ]
  end
end
