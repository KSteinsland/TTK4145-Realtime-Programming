defmodule Simulator do
  @valid_keys 'qwertyuisdfghjklzxcvbnm,.p-9870'

  def start_simulator(exec, port, floors, num_elevs, opts \\ []) do
    {:ok, dir_path} = File.cwd()
    script_path = Path.join(dir_path, "sim/start_sim.sh")
    exec_path = Path.join(dir_path, exec)
    args = [exec_path, to_string(port), to_string(floors), to_string(num_elevs)]
    args = args ++ get_extra_opts(opts)
    System.cmd(script_path, args)
    Process.sleep(500)
  end

  defp get_extra_opts(opts) do
    opts
    |> Enum.reduce([], fn {key, val}, acc -> ["--" <> to_string(key), to_string(val) | acc] end)
  end

  def send_key(key, elevator \\ 0) do
    if Enum.member?(@valid_keys, hd(to_charlist(key))) do
      {:ok, dir_path} = File.cwd()
      script_path = Path.join(dir_path, "sim/send_sim.sh")
      System.cmd(script_path, [to_string(key), to_string(elevator)])
    else
      IO.puts("Not a valid key!")
    end
  end
end
