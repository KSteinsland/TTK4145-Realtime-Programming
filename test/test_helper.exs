# Setup cleanup function, runs after all tests
ExUnit.after_suite(fn _ ->
  # Stops the cluster unless someone is attached
  System.cmd("bash", ["./test/scripts/stop_cluster.sh"])
end)

ExUnit.start()

# Loads support modules
{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

# Get config
port = Application.fetch_env!(:elevator_project, :port_driver)
floors = Application.fetch_env!(:elevator_project, :num_floors)
num_local_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

# If we want to stop all processes before running tests
# Supervisor.stop(ElevatorProject.Supervisor, :normal)

# If we want to just stop a process, i.e. the driver
# Supervisor.terminate_child(ElevatorProject.Supervisor, Driver)

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
    {:unix, :linux} ->
      IO.puts("Starting linux sim")

      Simulator.start_simulator(
        "sim/linux/SimElevatorServer",
        port,
        floors,
        num_local_nodes,
        opts
      )

    {:unix, :darwin} ->
      IO.puts("Starting mac sim")
      Simulator.start_simulator("sim/mac/SimElevatorServer", port, floors, num_local_nodes, opts)

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

  # create_cluster = fn num ->
  #   # primary is 0
  #   Enum.map(1..(num - 1), fn num ->
  #     String.to_atom("node" <> to_string(num) <> "@127.0.0.1")
  #   end)
  # end

  # This is bad and needs fixing!
  ElevatorProject.Application.start(nil, nil)
  Process.sleep(5_00)
  # Cluster.spawn(create_cluster.(num_local_nodes))
  System.cmd("bash", [
    "./test/scripts/start_cluster.sh",
    "$PWD",
    to_string(port + 1),
    to_string(num_local_nodes - 1)
  ])

  IO.puts("Started cluster")
end
