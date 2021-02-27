ExUnit.start()

start_simulator = fn(exec, port, floors)  ->
  {:ok, dir_path} = File.cwd()
  script_path = Path.join(dir_path, "sim/start_sim.sh")
  exec_path = Path.join(dir_path, exec)
  System.cmd(script_path, [exec_path, to_string(port), to_string(floors)])
  Process.sleep(1000)
end

port = 17777
floors = 4

case :os.type() do
  {:unix, :linux} ->
    IO.puts("Starting linux sim")
    start_simulator.("sim/linux/SimElevatorServer", port, floors)

  {:unix, :darwin} ->
    IO.puts("Starting mac sim")
    start_simulator.("sim/mac/SimElevatorServer", port, floors)

  _ ->
    {:error, "Not supported system"}

end
