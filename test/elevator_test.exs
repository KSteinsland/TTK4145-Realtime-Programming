defmodule ElevatorTest do
    use ExUnit.Case
    doctest Elevator

    setup do
        {:ok, pid} = Elevator.start_link
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
        assert Elevator.set_requests([]) == :ok
        assert Elevator.get_requests() == []
    end

    test "behaviour" do
        assert Elevator.set_behaviour(:idle) == :ok
        assert Elevator.get_behaviour() == :idle
    end
  end
