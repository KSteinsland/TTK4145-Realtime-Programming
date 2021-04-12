# Loads support modules
{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

# Setup cleanup function, runs after all tests
ExUnit.after_suite(fn _ ->
  # Stops the cluster unless someone is attached
  Cluster.cleanup()
end)

ExUnit.start()

# Get config
port = Application.fetch_env!(:elevator_project, :port_driver)
floors = Application.fetch_env!(:elevator_project, :num_floors)
num_local_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

# Exclude all external tests from running
ExUnit.configure(exclude: [external: true, distributed: true])

conf = ExUnit.configuration()

# check if we want to run integration tests
if conf[:include][:external] == "true" or conf[:include][:start_sim] do
  IO.puts("Running integration tests")

  opts =
    if conf[:include][:external] do
      # if we want integration tests to run fast
      Application.fetch_env!(:elevator_project, :sim_opts)
    else
      # just starting a normal simulator
      []
    end

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
else
  IO.puts("Running unit tests")
end

# check if we want to run distributed tests
if conf[:include][:distributed] == "true" do
  IO.puts("Running distributed tests")

  System.cmd("epmd", ["-daemon"])

  # Is this bad and needs fixing?
  ElevatorProject.Application.start(nil, nil)

  # Cluster.spawn(create_cluster.(num_local_nodes))
  Cluster.spawn(port + 1, num_local_nodes - 1)
  IO.puts("Started cluster")
end

# If we want to stop all processes before running tests
# Supervisor.stop(ElevatorProject.Supervisor, :normal)

# If we want to just stop a process, i.e. the driver
# Supervisor.terminate_child(ElevatorProject.Supervisor, Driver)
