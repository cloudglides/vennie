defmodule Vennie.MixProject do
  use Mix.Project

  def project do
    [
      app: :vennie,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Vennie.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
   {:nostrum, "~> 0.10"},
   {:porcelain, "~> 2.0"}
    ]
  end
end
