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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.4", runtime: false, only: :dev},
      {:credo, "~> 0.5", runtime: false, only: :dev},
      {:excoveralls, "~> 0.5", runtime: false, only: :test}
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
