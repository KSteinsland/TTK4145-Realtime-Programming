defmodule RequestsTest do
  use ExUnit.Case
  doctest Elevator

  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

  setup do
    # {:ok, pid} = Elevator.start_link([])
    #%{pid: pid}
    %{elevator: %Elevator{}}
  end

  #TODO fix this...
  defp update_requests(req, floor, btn_type, value) do
    {req_at_floor, _list} = List.pop_at(req, floor)
    updated_req_at_floor = List.replace_at(req_at_floor, @btn_types_map[btn_type], value)
    req = List.replace_at(req, floor, updated_req_at_floor)
  end

  test "requests above/below", %{elevator: elevator} do
    #assert Elevator.set_floor(1) == :ok
    elevator = %Elevator{elevator | floor: 1}
    #assert Requests.request_above?(elevator) == false
    #assert Requests.request_below?(elevator) == false

    #assert Elevator.set_request(1, :btn_hall_down) == :ok
    elevator = %Elevator{elevator | requests: update_requests(elevator.requests, 1, :btn_hall_down, 1)}
    #assert Requests.request_above?(elevator) == false
    #assert Requests.request_above?(elevator) == false

    #assert Elevator.set_request(2, :btn_hall_down) == :ok
    elevator = %Elevator{elevator | requests: update_requests(elevator.requests, 2, :btn_hall_down, 1)}
    #assert Requests.request_above?(elevator) == true
    #assert Requests.request_below?(elevator) == false

    #assert Elevator.set_floor(3) == :ok
    elevator = %Elevator{elevator | floor: 3}
    #assert Requests.request_above?(elevator) == false
    #assert Requests.request_below?(elevator) == true
  end
end
