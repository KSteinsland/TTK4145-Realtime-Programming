defmodule Cluster do
  def rpc(node, module, function, args) do
    :rpc.block_call(node, module, function, args)
  end

  def spawn(port, num) do
    System.cmd("bash", [
      "./test/scripts/start_cluster.sh",
      "$PWD",
      to_string(port),
      to_string(num)
    ])

    Process.sleep(6_000)
  end

  def cleanup() do
    # NB, only terminates the cluster if no one is attached to the tmux session!
    System.cmd("bash", ["./test/scripts/stop_cluster.sh"])
  end
end
