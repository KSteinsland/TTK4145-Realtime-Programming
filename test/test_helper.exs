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
ExUnit.configure(exclude: [external: true])

# check if we want to run integration test
conf = ExUnit.configuration()

if conf[:include][:external] == "true" do
  IO.puts("Running unit tests and integration tests")

  case :os.type() do
    {:unix, :linux} ->
      IO.puts("Starting linux sim")
      Simulator.start_simulator("sim/linux/SimElevatorServer", port, floors)

    {:unix, :darwin} ->
      IO.puts("Starting mac sim")
      Simulator.start_simulator("sim/mac/SimElevatorServer", port, floors, 2)

    _ ->
      IO.puts("You need to start the simulator yourself!")
      {:error, "Not supported system"}
  end
else
  IO.puts("Running unit tests")
end

# TODO implement this somehow...
# Cluster.spawn([:"node1@127.0.0.1", :"node2@127.0.0.1"])
