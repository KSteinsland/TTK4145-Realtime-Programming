defmodule ElevatorProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :elevator_project,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        test_unit: :test,
        test_integration: :test,
        test_distributed: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ElevatorProject.Application, []}
    ]
  end

  defp aliases do
    [
      test_unit: "test --no-start",
      test_integration: "test --no-start --include external:true",
      test_distributed: "test --no-start --include external:true --include distributed:true"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end
