defmodule ElevatorTest do
    use ExUnit.Case
    doctest Elevator
  
    setup do
        {:ok, pid} = Elevator.start_link
        %{pid: pid}
    end

    test "floor", %{pid: pid} do
        assert Elevator.set_floor(pid, 2) == :ok
        assert Elevator.get_floor(pid) == 2
    end
    
    test "direction", %{pid: pid} do
        assert Elevator.set_direction(pid, :up) == :ok
        assert Elevator.get_direction(pid) == :up
    end

    test "requests", %{pid: pid} do
        assert Elevator.set_request(pid, []) == :ok
        assert Elevator.get_request(pid) == []
    end

    test "behaviour", %{pid: pid} do
        assert Elevator.set_behaviour(pid, :idle) == :ok
        assert Elevator.get_behaviour(pid) == :idle
    end
  end
  