defmodule NetworkTest do
  use ExUnit.Case
  doctest Network

  test "finds local ip" do
    {:ok, local_ip} = Network.Util.get_local_ip()

    assert :inet.getif()
           |> elem(1)
           |> Enum.map(fn x -> elem(x, 0) end)
           |> Enum.find(&match?(^local_ip, &1)) ==
             local_ip
  end
end

defmodule NodeConnectorTest do
  use ExUnit.Case, async: false
  @moduletag :distributed
  doctest NodeConnector

  setup do
    System.cmd("epmd", ["-daemon"])
    port = 33333

    case NodeConnector.start_link([port, "test_udp"]) do
      {:ok, _pid} ->
        :ok

      {:error, _err_msg} ->
        :ok
    end
  end

  # We have to do this in one big test, as tests are done in random order!
  # TODO this test needs fixing!
  test "Check NodeConnector" do
    # Check local role
    Process.sleep(5_000)
    assert NodeConnector.get_role() == :master

    # Check for other nodes
    Process.sleep(5_000)
    # IO.inspect(NodeConnector.get_state())
    assert length(Map.keys(NodeConnector.get_all_slaves())) ==
             Application.fetch_env!(:elevator_project, :local_nodes) - 1

    # Check that the slaves are behaving properly
    Node.list()
    |> Enum.map(fn node ->
      assert Cluster.rpc(node, NodeConnector, :get_role, []) == :slave
      state = Cluster.rpc(node, NodeConnector, :get_state, [])
      assert state.master == Node.self()
    end)

    # Check that someone takes over when we die
    Process.whereis(NodeConnector) |> Process.exit(:kill)
    Process.sleep(10_000)
    assert NodeConnector.get_role() == :slave

    assert Node.list()
    |> Enum.any?(fn node ->
      Cluster.rpc(node, NodeConnector, :get_role, []) == :master
    end)
  end

  # test "kill slave" do
  #   node = Enum.at(Node.list(),0)
  #   Cluster.rpc(node, ElevatorProject.Application, :kill, [])
  #   Process.sleep(10_000)
  # end

  # test "going down" do
  #   Node.stop
  #   Process.sleep(10_000)
  # end
end
