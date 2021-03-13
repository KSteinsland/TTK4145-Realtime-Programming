defmodule RequestsTest do
  use ExUnit.Case
  doctest Elevator

  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

  setup do
    %{elevator: %Elevator{}}
  end

  # TODO fix this...
  defp update_requests(req, floor, btn_type, value) do
    {req_at_floor, _list} = List.pop_at(req, floor)
    updated_req_at_floor = List.replace_at(req_at_floor, @btn_types_map[btn_type], value)
    List.replace_at(req, floor, updated_req_at_floor)
  end

  # TODO split this up in smaller tests and good tests

  test "requests above/below", %{elevator: elevator} do
    elevator = %Elevator{elevator | floor: 1}

    assert Requests.should_stop?(elevator) == true
    assert Requests.choose_direction(elevator) == :dir_stop
    assert Requests.clear_at_current_floor(elevator) == elevator

    elevator = %Elevator{
      elevator
      | requests: update_requests(elevator.requests, 1, :btn_hall_down, 1)
    }

    assert Requests.should_stop?(elevator) == true
    assert Requests.choose_direction(elevator) == :dir_stop

    assert Requests.clear_at_current_floor(elevator) == %Elevator{
             elevator
             | requests: update_requests(elevator.requests, 1, :btn_hall_down, 0)
           }

    elevator = %Elevator{
      elevator
      | requests: update_requests(elevator.requests, 2, :btn_hall_down, 1)
    }

    assert Requests.should_stop?(elevator) == true
    assert Requests.choose_direction(elevator) == :dir_up

    assert Requests.clear_at_current_floor(elevator) == %Elevator{
             elevator
             | requests: update_requests(elevator.requests, 1, :btn_hall_down, 0)
           }

    elevator = %Elevator{elevator | floor: 3}
  end
end
