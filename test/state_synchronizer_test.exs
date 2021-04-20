defmodule StateSynchronizerTest do
  use ExUnit.Case, async: false
  @moduletag :distributed
  doctest StateSynchronizer

  setup_all do
    # Ensures that the cluster is in a known state before next distributed test
    on_exit(fn ->
      Cluster.spawn(
        Application.fetch_env!(:elevator_project, :port_driver) + 1,
        Application.fetch_env!(:elevator_project, :local_nodes) - 1
      )
    end)
  end

  test "test state distribution" do
    IO.puts("State dist test")

    # nodes = [Node.list(), node()]
    valid_buttons = "qwesdfzxcv" |> String.split("", trim: true)

    num_nodes = Application.fetch_env!(:elevator_project, :local_nodes)

    # sending a bunch of random button presses
    Enum.map(0..10, fn _num ->
      valid_buttons
      |> Enum.random()
      |> Simulator.send_key(Enum.random(0..(num_nodes - 1)))
    end)

    Process.sleep(500)

    Enum.map(Node.list(), fn node ->
      # Cluster.rpc(node, Driver, :set_motor_direction, [:dir_stop])
      pid = Cluster.rpc(node, Process, :whereis, [NodeConnector])
      Cluster.rpc(node, Process, :exit, [pid, :kill])
    end)

    # Process.sleep(4_000)

    # check that state is the same on all nodes
    system_state = StateServer.get_state()

    Enum.map(Node.list(), fn node ->
      assert Cluster.rpc(node, StateServer, :get_state, []) == system_state
      IO.puts("checking node #{node}")
    end)
  end

  # TODO test disconnecting a node and reconnecting it
  # test killing a node
end
