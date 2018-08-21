defmodule Sparrow.MixProject do
  use Mix.Project

  def project do
    [
      app: :sparrow,
      version: "0.1.0",
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
      extra_applications: [:lager, :logger, :chatterbox]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.4", runtime: false, only: [:dev, :test]},
      {:credo, "~> 0.5", runtime: false, only: :dev},
      {:chatterbox, github: "joedevivo/chatterbox", tag: "7a3c64d"},
      {:excoveralls, "~> 0.5", runtime: false, only: :test},
      {:quixir, "~> 0.9", only: :test},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.1"},
      {:joken, "~> 2.0-rc0"},
      {:poison, "~> 3.1"},
      {:mock, "~> 0.3.0", only: :test},
      {:cowboy, "~> 2.4.0", only: :test},
      {:lager, ">= 3.2.1", override: true},
      {:logger_lager_backend, "~> 0.1.0"},
      {:plug, "1.6.1", only: :test}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: ".dialyzer/",
      flags: ["-Wunmatched_returns", "-Werror_handling", "-Wrace_conditions", "-Wunderspecs"],
      plt_add_apps: [:mix]
    ]
  end

  defp test_coverage do
    [tool: ExCoveralls]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/helpers"]

  defp elixirc_paths(_), do: ["lib"]
end
