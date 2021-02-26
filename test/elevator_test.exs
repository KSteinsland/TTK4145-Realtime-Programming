defmodule ElevatorTest do
    use ExUnit.Case
    doctest Elevator

    setup do
        {:ok, pid} = Elevator.start_link
        %{pid: pid}
    end

    test "floor" do
        assert Elevator.set_floor(2) == :ok
        assert Elevator.get_floor() == 2
    end

    test "direction" do
        assert Elevator.set_direction(:up) == :ok
        assert Elevator.get_direction() == :up
    end

    test "requests" do
        assert Elevator.get_requests() == [[0,0,0], [0,0,0], [0,0,0], [0,0,0]]
        assert Elevator.set_request(1, 1) == :ok
        assert Elevator.get_requests() == [[0,0,0], [0,1,0], [0,0,0], [0,0,0]]
    end

    test "behaviour" do
        assert Elevator.set_behaviour(:idle) == :ok
        assert Elevator.get_behaviour() == :idle
    end
  end
