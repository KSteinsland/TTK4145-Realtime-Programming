defmodule ElevatorTest do
  use ExUnit.Case
  doctest Elevator

  test "floor" do
    el = %Elevator{floor: 0}
    assert Elevator.new(el) == el

    el = %Elevator{floor: -2}
    new_el = Elevator.new(el)
    assert :error == Enum.at(Tuple.to_list(new_el), 0)

    el = %Elevator{floor: 1000}
    new_el = Elevator.new(el)
    assert :error == Enum.at(Tuple.to_list(new_el), 0)
  end

  test "direction" do
    el = %Elevator{direction: :dir_stop}
    assert Elevator.new(el) == el

    el = %Elevator{direction: 42}
    new_el = Elevator.new(el)
    assert :error == Enum.at(Tuple.to_list(new_el), 0)

    el = %Elevator{direction: "test"}
    new_el = Elevator.new(el)
    assert :error == Enum.at(Tuple.to_list(new_el), 0)
  end

  test "requests" do
    el = %Elevator{}
    reqs = el.requests

    new_reqs = Elevator.update_requests(reqs, 2, :btn_cab, 1)
    new_el = %Elevator{el | requests: new_reqs}
    assert Elevator.new(new_el) == new_el

    new_reqs = Elevator.update_requests(reqs, -2, :btn_cab, 1)
    assert :error == Enum.at(Tuple.to_list(new_reqs), 0)

    new_reqs = Elevator.update_requests(reqs, 0, :btn_cab, -1)
    assert :error == Enum.at(Tuple.to_list(new_reqs), 0)

    new_reqs = Elevator.update_requests(reqs, 0, :btn_wrong, 1)
    assert :error == Enum.at(Tuple.to_list(new_reqs), 0)
  end

  test "behaviour" do
    el = %Elevator{behaviour: :be_idle}
    new_el = Elevator.new(el)
    assert new_el == el

    el = %Elevator{behaviour: 42}
    new_el = Elevator.new(el)
    assert :error == Enum.at(Tuple.to_list(new_el), 0)

    el = %Elevator{behaviour: "test"}
    new_el = Elevator.new(el)
    assert :error == Enum.at(Tuple.to_list(new_el), 0)
  end
end
