ExUnit.start()

start_simulator_mac = fn(port, floors)  ->
  {:ok, dir_path} = File.cwd()
  script_path = Path.join(dir_path, "sim/start_sim_mac.sh")
  exec_path = Path.join(dir_path, "sim/SimElevatorServer")
  System.cmd(script_path, [exec_path, to_string(port), to_string(floors)])
  Process.sleep(1000)
end

start_simulator_linux = fn(port, floors)  ->
  {:ok, dir_path} = File.cwd()
  script_path = Path.join(dir_path, "sim/start_sim.sh")
  exec_path = Path.join(dir_path, "sim/SimElevatorServer")
  System.cmd(script_path, [exec_path, to_string(port), to_string(floors)])
  Process.sleep(1000)
end

port = 17777
floors = 4


case :os.type() do
  {:unix, :linux} ->
    IO.puts("Starting linux sim")
    start_simulator_linux.(port, floors)
    
  {:unix, :darwin} ->
    IO.puts("Starting mac sim")
    start_simulator_mac.(port, floors)

  _ ->
    {:error, "Not supported system"}

end
