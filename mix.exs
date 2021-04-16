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
      test_integration: [&start_sim/1, "test --no-start --only external:true"],
      test_distributed: [
        &start_sim/1,
        "test --no-start --only distributed:true"
      ],
      start_sim: &start_sim/1,
      start_cluster: &start_cluster/1,
      open_sim: &open_sim/1,
      open_cluster: &open_cluster/1
    ]
  end

  defp start_sim(_) do
    # Load simulator support module
    Code.require_file("test/support/simulator.exs", __DIR__)

    # Get config
    port = Application.fetch_env!(:elevator_project, :port_driver)
    floors = Application.fetch_env!(:elevator_project, :num_floors)
    num_local_nodes = Application.fetch_env!(:elevator_project, :local_nodes)
    opts = []
    # opts = Application.fetch_env!(:elevator_project, :sim_opts)

    case :os.type() do
      {:unix, os} ->
        os = if os == :linux, do: to_string(os), else: "mac"
        IO.puts("Starting #{os} sim")

        Simulator.start_simulator(
          "sim/#{os}/SimElevatorServer",
          port,
          floors,
          num_local_nodes,
          opts
        )

      _ ->
        IO.puts("You need to start the simulator yourself!")
        {:error, "Not supported system"}
    end
  end

  defp open_sim(_) do
    start_sim(nil)

    {:ok, dir_path} = File.cwd()
    script_path = Path.join(dir_path, "test/scripts/open_sim.sh")
    System.cmd(script_path, [])
  end

  defp open_cluster(_) do
    start_cluster(nil)

    {:ok, dir_path} = File.cwd()
    script_path = Path.join(dir_path, "test/scripts/open_cluster.sh")
    System.cmd(script_path, [])
  end

  defp start_cluster(_) do
    # Load simulator support module
    Code.require_file("test/support/cluster.exs", __DIR__)

    # Get config
    port = Application.fetch_env!(:elevator_project, :port_driver)
    num_local_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

    System.cmd("epmd", ["-daemon"])

    Cluster.spawn(port + 1, num_local_nodes - 1)
    IO.puts("Started cluster")
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:json, "~> 1.4"}
    ]
  end
end
