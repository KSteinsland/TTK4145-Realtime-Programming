defmodule ElevatorProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :elevator_project,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      #aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ElevatorProject.Application, []}
    ]
  end

  # defp aliases do
  #   [
  #     test: "test --no-start" #(2)
  #   ]
  # end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
