defmodule Isuumo.MixProject do
  use Mix.Project

  def project do
    [
      app: :isuumo,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Isuumo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:plug, "~> 1.10"},
      {:cowboy, "~> 2.8"},
      {:plug_cowboy, "~> 2.3"},
      {:ecto, "~> 3.4"},
      {:ecto_sql, "~> 3.0"},
      {:myxql, "~> 0.4.0"},
      {:poison, "~> 4.0"}
    ]
  end
end
