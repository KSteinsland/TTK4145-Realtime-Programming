defmodule RequestsTest do
  use ExUnit.Case
  doctest Elevator

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons 3

  setup do
    %{elevator: %Elevator{}}
  end

  test "request above", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 0}

    assert Requests.request_above?(elevator) == false

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 1)
    }

    assert Requests.request_above?(elevator) == true
  end

  test "request below", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 2}

    assert Requests.request_below?(elevator) == false

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 1)
    }

    assert Requests.request_below?(elevator) == true
  end

  test "choose direction", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 0}
    assert Requests.choose_direction(elevator) == :dir_stop

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 1)
    }

    assert Requests.choose_direction(elevator) == :dir_up

    elevator = %Elevator{elevator | floor: 3}
    assert Requests.choose_direction(elevator) == :dir_down
  end

  test "should stop", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 0}
    assert Requests.should_stop?(elevator) == true

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 2, :btn_hall_down, 1)
    }

    elevator = %Elevator{
      elevator
      | direction: Requests.choose_direction(elevator)
    }

    elevator = %Elevator{elevator | floor: 1}
    assert Requests.should_stop?(elevator) == false

    elevator = %Elevator{elevator | floor: 2}
    assert Requests.should_stop?(elevator) == true
  end

  test "clear_at_current_floor", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 0}

    assert elevator == Requests.clear_at_current_floor(elevator)

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 1)
    }

    assert elevator == Requests.clear_at_current_floor(elevator)

    elevator = %Elevator{elevator | floor: 1}
    empty_request_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    assert Requests.clear_at_current_floor(elevator).requests == empty_request_list
  end

  test "full module test", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 1}

    assert Requests.should_stop?(elevator) == true
    assert Requests.choose_direction(elevator) == :dir_stop
    assert Requests.clear_at_current_floor(elevator) == elevator

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 1)
    }

    assert Requests.should_stop?(elevator) == true
    assert Requests.choose_direction(elevator) == :dir_stop

    assert Requests.clear_at_current_floor(elevator) == %Elevator{
             elevator
             | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 0)
           }

    elevator = %Elevator{
      elevator
      | requests: Elevator.update_requests(elevator.requests, 2, :btn_hall_down, 1)
    }

    assert Requests.should_stop?(elevator) == true
    assert Requests.choose_direction(elevator) == :dir_up

    assert Requests.clear_at_current_floor(elevator) == %Elevator{
             elevator
             | requests: Elevator.update_requests(elevator.requests, 1, :btn_hall_down, 0)
           }

    _elevator = %Elevator{elevator | floor: 3}
  end
end
