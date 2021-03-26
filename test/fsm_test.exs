defmodule FSMTest do
  use ExUnit.Case
  doctest FSM, async: false

  # setup do
  #   Application.stop(:kv)
  #   :ok = Application.start(:kv)
  # end

  # when code is more reliable we can expand to integration testing, by starting our whole application,
  # and using the processes started in the application, instead of explicity starting them as done below

  defp wait_for_floor(floor_n) do
    if Driver.get_floor_sensor_state() == floor_n do
      floor_n
    else
      wait_for_floor(floor_n)
    end
  end

  setup_all do
    # todo, move this to a integration test
    # port = 17777
    # {:ok, elevator_driver_pid} = Driver.start_link([{127, 0, 0, 1}, port])
    # {:ok, elevator_pid} = Elevator.start_link([])
    # %{pid: elevator_pid}

    # %{elevator: %Elevator{}}
    :ok
  end

  test "just arrived at a floor" do
    elevator = %Elevator{
      floor: 2,
      behaviour: :be_moving
    }

    new_floor = 0
    {action, elevator} = FSM.on_floor_arrival(elevator, new_floor)

    assert {action, elevator} == {:stop, %Elevator{elevator | floor: new_floor}}
    assert elevator.behaviour == :be_door_open

    elevator = %Elevator{
      floor: 2,
      behaviour: :be_door_open
    }

    new_floor = 0
    {action, elevator} = FSM.on_floor_arrival(elevator, new_floor)

    assert {action, elevator} == {nil, %Elevator{elevator | floor: new_floor}}
    assert elevator.behaviour == :be_door_open

    elevator = %Elevator{
      floor: 2,
      behaviour: :be_idle
    }

    new_floor = 0
    {action, elevator} = FSM.on_floor_arrival(elevator, new_floor)

    assert {action, elevator} == {nil, %Elevator{elevator | floor: new_floor}}
    assert elevator.behaviour == :be_idle
  end
end
