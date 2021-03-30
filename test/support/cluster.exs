defmodule Cluster do
  def spawn(nodes) do
    # Turn node into a distributed node with the given long name

    main_node =
      if Node.self() == :nonode@nohost do
        Node.start(:"primary@127.0.0.1")
        :"primary@127.0.0.1"
      else
        Node.self()
      end

    :net_kernel.start([main_node])

    {:ok, ip_tup} = Network.Util.get_local_ip()
    ip = :inet.ntoa(ip_tup)

    # Allow spawned nodes to fetch all code from this node
    :erl_boot_server.start([])
    allow_boot(to_charlist(ip))

    nodes
    |> Enum.with_index()
    |> Enum.map(&Task.async(fn -> spawn_node(&1, ip) end))
    |> Enum.map(&Task.await(&1, 30_000))
  end

  defp spawn_node({node_host, ind}, ip) do
    {:ok, node} = :slave.start(to_charlist(ip), node_name(node_host), inet_loader_args(ip))
    Process.sleep(100)
    add_code_paths(node)
    transfer_configuration(node, ind)
    ensure_applications_started(node)
    # start_pubsub(node)
    # rpc lets you start function at remote node!
    {:ok, node}
  end

  def rpc(node, module, function, args) do
    :rpc.block_call(node, module, function, args)
  end

  defp inet_loader_args(ip) do
    to_charlist("-loader inet -hosts #{ip} -setcookie #{:erlang.get_cookie()}")
  end

  defp allow_boot(host) do
    {:ok, ipv4} = :inet.parse_ipv4_address(host)
    :erl_boot_server.add_slave(ipv4)
  end

  defp add_code_paths(node) do
    rpc(node, :code, :add_paths, [:code.get_path()])
  end

  defp transfer_configuration(node, ind) do
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        val = if key == :port_driver, do: val + 1 + ind

        rpc(node, Application, :put_env, [app_name, key, val])
      end
    end
  end

  defp ensure_applications_started(node) do
    rpc(node, Application, :ensure_all_started, [:mix])
    rpc(node, Mix, :env, [Mix.env()])

    for {app_name, _, _} <- Application.loaded_applications() do
      rpc(node, Application, :ensure_all_started, [app_name])
    end
  end

  # defp start_pubsub(node) do
  #   args = [
  #     [{Phoenix.PubSub, name: Phoenix.PubSubTest, pool_size: 1}],
  #     [strategy: :one_for_one]
  #   ]

  #   rpc(node, Supervisor, :start_link, args)
  # end

  defp node_name(node_host) do
    node_host
    |> to_string
    |> String.split("@")
    |> Enum.at(0)
    |> String.to_atom()
  end
end
