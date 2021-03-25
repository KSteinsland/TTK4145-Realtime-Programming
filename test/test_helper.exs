ExUnit.start()

# Loads support modules
{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

# Get config
port = Application.fetch_env!(:elevator_project, :port_driver)
floors = Application.fetch_env!(:elevator_project, :num_floors)

# If we want to stop all processes before running tests
# Supervisor.stop(ElevatorProject.Supervisor, :normal)

# If we want to just stop a process, i.e. the driver
# Supervisor.terminate_child(ElevatorProject.Supervisor, Driver)

# Exclude all external tests from running
ExUnit.configure(exclude: [external: true, distributed: true])

conf = ExUnit.configuration()

num_local_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

# check if we want to run integration tests
if conf[:include][:external] == "true" do
  IO.puts("Running unit tests and integration tests")

  case :os.type() do
    {:unix, :linux} ->
      IO.puts("Starting linux sim")
      Simulator.start_simulator("sim/linux/SimElevatorServer", port, floors)

    {:unix, :darwin} ->
      IO.puts("Starting mac sim")
      Simulator.start_simulator("sim/mac/SimElevatorServer", port, floors, num_local_nodes)

    _ ->
      IO.puts("You need to start the simulator yourself!")
      {:error, "Not supported system"}
  end
else
  IO.puts("Running unit tests")
end

# check if we want to run distributed tests
if conf[:include][:distributed] == "true" do
  create_cluster = fn num ->
    # primary is 0
    Enum.map(1..(num - 1), fn num ->
      String.to_atom("node" <> to_string(num) <> "@127.0.0.1")
    end)
  end

  # This is bad and needs fixing!
  ElevatorProject.Application.start(nil, nil)
  Process.sleep(1_000)
  Cluster.spawn(create_cluster.(num_local_nodes))
  IO.puts("Started cluster")
end
