defmodule ElevatorTest do
  use ExUnit.Case
  doctest Elevator

  test "floor" do
    el = %Elevator{floor: 0}
    assert Elevator.check(el) == {:ok, el}

    el = %Elevator{floor: -2}
    {status, _el} = Elevator.check(el)
    assert status == :error

    el = %Elevator{floor: 1000}
    {status, _el} = Elevator.check(el)
    assert status == :error
  end

  test "direction" do
    el = %Elevator{direction: :dir_stop}
    assert Elevator.check(el) == {:ok, el}

    el = %Elevator{direction: 42}
    {status, _el} = Elevator.check(el)
    assert status == :error

    el = %Elevator{direction: "test"}
    {status, _el} = Elevator.check(el)
    assert status == :error
  end

  test "requests" do
    el = %Elevator{}
    reqs = el.requests

    new_reqs = Elevator.update_requests(reqs, 2, :btn_cab, 1)
    new_el = %Elevator{el | requests: new_reqs}
    assert Elevator.check(new_el) == {:ok, new_el}

    new_reqs = Elevator.update_requests(reqs, -2, :btn_cab, 1)
    assert :error == Enum.at(Tuple.to_list(new_reqs), 0)

    new_reqs = Elevator.update_requests(reqs, 0, :btn_cab, -1)
    assert :error == Enum.at(Tuple.to_list(new_reqs), 0)

    new_reqs = Elevator.update_requests(reqs, 0, :btn_wrong, 1)
    assert :error == Enum.at(Tuple.to_list(new_reqs), 0)
  end

  test "behaviour" do
    el = %Elevator{behaviour: :be_idle}
    {:ok, new_el} = Elevator.check(el)
    assert new_el == el

    el = %Elevator{behaviour: 42}
    {status, _el} = Elevator.check(el)
    assert status == :error

    el = %Elevator{behaviour: "test"}
    {status, _el} = Elevator.check(el)
    assert status == :error
  end
end
