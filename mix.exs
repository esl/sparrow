defmodule Sparrow.MixProject do
  use Mix.Project

  def project do
    [
      app: :sparrow,
      version: "1.0.2",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: test_coverage()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Sparrow, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", runtime: false, only: [:dev, :test]},
      {:credo, "~> 1.6", runtime: false, only: [:dev, :test]},
      {:chatterbox, github: "joedevivo/chatterbox", ref: "1f4ce4f"},
      {:certifi, "~> 2.9"},
      {:excoveralls, "~> 0.14", runtime: false, only: :test},
      {:quixir, "~> 0.9", only: :test},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:joken, "~> 2.5"},
      {:poison, "~> 5.0"},
      {:mox, "~> 1.0", only: :test},
      {:mock, "~> 0.3", only: :test},
      {:meck, github: "eproxus/meck", only: :test, override: true},
      {:cowboy, "~> 2.9", only: :test},
      {:lager, "~> 3.9", override: true},
      {:logger_lager_backend, "~> 0.2"},
      {:plug, "~> 1.13", only: :test},
      {:goth, "~> 1.1.0", runtime: false},
      {:httpoison, "~> 1.8"},
      {:worker_pool, "== 4.0.1"},
      {:assert_eventually, "~> 1.0", only: [:test]},
      {:telemetry, "~> 1.1"}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: ".dialyzer",
      flags: [
        :unmatched_returns,
        :error_handling,
        :underspecs
      ],
      plt_add_apps: [:mix, :goth]
    ]
  end

  defp test_coverage do
    [tool: ExCoveralls]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/helpers"]

  defp elixirc_paths(_), do: ["lib"]

  defp elixirc_options() do
    [warnings_as_errors: true]
  end
end
