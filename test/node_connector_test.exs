defmodule NodeConnectorTest do
  use ExUnit.Case, async: false
  @moduletag :distributed
  doctest NodeConnector

  setup_all do
    port = 34444
    num_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

    case NodeConnector.start_link([port, "test_udp"]) do
      {:ok, _pid} ->
        :ok

      {:error, _err_msg} ->
        :ok
    end

    # Ensures that the cluster is in a known state before next distributed test
    on_exit(fn ->
      Cluster.spawn(
        Application.fetch_env!(:elevator_project, :port_driver) + 1,
        num_nodes - 1
      )
    end)

    %{num_nodes: num_nodes}
  end

  # We have to do this in one big test, as tests are done in random order!
  # TODO this test needs fixing!
  test "Check NodeConnector", fixture do
    # Check local role
    Process.sleep(5_000)
    local_state = :sys.get_state(NodeConnector)
    assert local_state.role == :master

    # Check for other nodes
    Process.sleep(5_000)
    assert local_state.slaves |> Map.keys() |> length() == fixture.num_nodes - 1

    # Check that the slaves are behaving properly
    Node.list()
    |> Enum.map(fn node ->
      state = Cluster.rpc(node, :sys, :get_state, [NodeConnector])
      assert state.role == :slave
      assert state.master == local_state.master
    end)

    # Test slave loosing and restoring internet
    slave = Node.list() |> Enum.at(0)
    Cluster.rpc(slave, NodeConnector, :dev_network_loss, [7000])
    new_local_state = :sys.get_state(NodeConnector)
    assert Node.list() |> length() == fixture.num_nodes - 1
    Process.sleep(8_000)
    assert Node.list() |> length() == fixture.num_nodes
    assert :sys.get_state(NodeConnector).slaves == local_state.slaves

    # # Check that someone takes over when we die
    # Process.whereis(NodeConnector) |> Process.exit(:kill)
    # Process.sleep(5_000)
    # assert NodeConnector.get_role() == :slave

    # assert Node.list()
    #        |> Enum.any?(fn node ->
    #          Cluster.rpc(node, NodeConnector, :get_role, []) == :master
    #        end)

    Process.sleep(2_000)
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
