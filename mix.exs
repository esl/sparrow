defmodule Sparrow.MixProject do
  use Mix.Project

  def project do
    [
      app: :sparrow,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: test_coverage()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :chatterbox]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.4", runtime: false, only: :dev},
      {:credo, "~> 0.5", runtime: false, only: :dev},
      {:chatterbox, github: "joedevivo/chatterbox", tag: "7a3c64d"},
      {:excoveralls, "~> 0.5", runtime: false, only: :test},
      {:quixir, "~> 0.9", only: :test},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: ".dialyzer/",
      flags: ["-Wunmatched_returns", "-Werror_handling", "-Wrace_conditions", "-Wunderspecs"]
    ]
  end

  defp test_coverage do
    [tool: ExCoveralls]
  end
end
