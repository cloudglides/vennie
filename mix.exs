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
      {:plug, "~> 1.15"},
     {:bandit, "~> 1.0"},
      {:nostrum, github: "Kraigie/nostrum"},
      {:telemetry, "~> 1.0"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},
      {:jason, "~> 1.2"},
      {:porcelain, "~> 2.0"},
      {:httpoison, "~> 2.0"},
      {:hackney, "~> 1.18"},
      {:idna, "~> 6.1"},
      {:unicode_util_compat, "~> 0.4"},
      {:mimerl, "~> 1.2"},
      {:parse_trans, "~> 3.3"}
    ]
  end
end
