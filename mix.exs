defmodule Sparrow.MixProject do
  use Mix.Project

  def project do
    [
      app: :sparrow,
      version: "1.0.2",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:dialyxir, "~> 0.4", runtime: false, only: [:dev, :test]},
      {:credo, "~> 0.10", runtime: false, only: :dev},
      {:chatterbox, github: "joedevivo/chatterbox", ref: "1f4ce4f"},
      {:certifi, "~> 2.5.1"},
      {:excoveralls, "~> 0.5", runtime: false, only: :test},
      {:quixir, "~> 0.9", only: :test},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.1"},
      {:joken, "~> 2.0-rc0"},
      {:poison, "~> 3.1"},
      {:mox, "~> 0.5", only: :test},
      {:mock, "~> 0.3.0", only: :test},
      {:meck, github: "eproxus/meck", override: true},
      {:cowboy, "~> 2.4.0", only: :test},
      {:lager, ">= 3.2.1", override: true},
      {:logger_lager_backend, "~> 0.1.0"},
      {:plug, "1.6.1", only: :test},
      {:goth, "~> 1.1.0", runtime: false},
      {:httpoison, "~> 0.11 or ~> 1.0"},
      {:worker_pool, "== 4.0.1"},
      {:assert_eventually, "~> 0.2.0", only: [:test]},
      {:telemetry, "~>0.4.1"}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: ".dialyzer/",
      flags: [
        "-Wunmatched_returns",
        "-Werror_handling",
        "-Wrace_conditions",
        "-Wunderspecs"
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
end
