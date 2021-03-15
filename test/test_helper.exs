ExUnit.start()

# Loads support modules
{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

port = 17777
floors = 4

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

# Cluster.spawn([:"node1@127.0.0.1", :"node2@127.0.0.1"])
