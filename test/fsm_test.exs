defmodule FSMTest do
  use ExUnit.Case
  doctest FSM

  describe "On request button pressed" do
    test "door open" do
      elevator = %Elevator{
        floor: 2,
        behaviour: :be_door_open
      }

      {action, new_elevator} = FSM.on_request_button_press(elevator, 2, :btn_cab)
      assert action == :start_timer
      assert elevator == new_elevator

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_cab)
      assert action == nil
      assert elevator.requests != new_elevator.requests

      {action, new_elevator} = FSM.on_request_button_press(elevator, 2, :btn_hall_up)
      assert action == :start_timer
      assert elevator == new_elevator

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_hall_up)
      assert action == :update_hall_requests
      assert elevator == new_elevator
    end

    test "moving" do
      elevator = %Elevator{
        floor: 2,
        behaviour: :be_moving
      }

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_cab)
      assert action == nil
      assert elevator.requests != new_elevator.requests

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_hall_up)
      assert action == :update_hall_requests
      assert elevator == new_elevator
    end

    test "idle" do
      elevator = %Elevator{
        floor: 2,
        behaviour: :be_idle
      }

      {action, new_elevator} = FSM.on_request_button_press(elevator, 2, :btn_cab)
      assert action == :open_door
      assert new_elevator.behaviour == :be_door_open

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_cab)
      assert action == :move_elevator
      assert new_elevator.behaviour == :be_moving
      assert elevator.requests != new_elevator.requests

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_hall_up)
      assert action == :update_hall_requests
      assert elevator == new_elevator
    end

    test "not valid" do
      elevator = %Elevator{
        floor: 2,
        behaviour: :not_valid
      }

      {action, new_elevator} = FSM.on_request_button_press(elevator, 1, :btn_cab)
      assert action == nil
      assert new_elevator == elevator
    end
  end

  test "just arrived at a floor" do
    elevator = %Elevator{
      floor: 2,
      behaviour: :be_moving
    }

    new_floor = 0

    {action, new_elevator} = FSM.on_floor_arrival(elevator, new_floor)

    assert action == :stop
    assert new_elevator.behaviour == :be_door_open

    elevator = %Elevator{
      floor: 2,
      behaviour: :be_door_open
    }

    {action, new_elevator} = FSM.on_floor_arrival(elevator, new_floor)

    assert action == nil
    assert new_elevator == %Elevator{elevator | floor: new_floor}

    elevator = %Elevator{
      floor: 2,
      behaviour: :be_idle
    }

    {action, new_elevator} = FSM.on_floor_arrival(elevator, new_floor)

    assert action == nil
    assert new_elevator == %Elevator{elevator | floor: new_floor}
  end

  test "door closing" do
    elevator = %Elevator{
      floor: 2,
      behaviour: :be_door_open,
      direction: :dir_stop
    }

    {action, new_elevator} = FSM.on_door_timeout(elevator)

    assert action == :close_doors
    assert new_elevator.behaviour == :be_idle

    elevator = %Elevator{
      floor: 2,
      behaviour: :be_moving
    }

    {action, new_elevator} = FSM.on_door_timeout(elevator)

    assert action == nil
    assert new_elevator == elevator
  end
end
