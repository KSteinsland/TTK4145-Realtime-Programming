defmodule StateServerTest do
    use ExUnit.Case, async: false
    @moduletag :distributed
    doctest StateServer

    test "test state server" do
        IO.puts("\nState Server test")

        #go to bottom floor
        Simulator.send_key('z', 1)
        Simulator.send_key('z', 2)
        Process.sleep(5_000)

        slaves = NodeConnector.get_all_slaves()
        el1 = String.to_atom("node1@" <> Enum.at(slaves["node1"],0))
        el2 = String.to_atom("node2@" <> Enum.at(slaves["node2"],0))

        IO.inspect(el1)
        IO.inspect(el2)

        assert Cluster.rpc(el1, StateInterface, :get_state, []).floor == 0
        assert Cluster.rpc(el2, StateInterface, :get_state, []).floor == 0

        #give orders on two elevators at the same time 
        Simulator.send_key('c', 1)
        Simulator.send_key('v', 2)
        Process.sleep(500)

        #assert that both orders where received
        sys_state = Cluster.rpc(el1, StateServer, :get_state, []) 
        sys_state |> IO.inspect
        assert sys_state.elevators[el1].requests |>  Enum.at(2) |> Enum.at(2)  == 1
        assert sys_state.elevators[el2].requests |>  Enum.at(3) |> Enum.at(2)  == 1
    end
end
  