defmodule DriverTest do
  use ExUnit.Case
  @moduletag :external
  doctest Driver, async: false

  defp wait_for_floor(state) do
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        wait_for_floor(state)

      floor ->
        floor
    end
  end

  setup_all do
    port = Application.fetch_env!(:elevator_project, :port_driver)
    floors = Application.fetch_env!(:elevator_project, :num_floors)
    {:ok, pid} = Driver.start_link([{127, 0, 0, 1}, port])
    %{pid: pid, floors: floors}
  end

  test "testing init state", %{floors: floors} do
    floor = Driver.get_floor_sensor_state()
    assert is_number(floor) || floor == :between_floors
    assert Driver.get_obstruction_switch_state() == :inactive
    assert Driver.get_stop_button_state() == :inactive

    for floor <- 0..(floors - 1) do
      assert Driver.get_order_button_state(floor, :btn_hall_up) == 0
      assert Driver.get_order_button_state(floor, :btn_hall_down) == 0
      assert Driver.get_order_button_state(floor, :btn_cab) == 0
    end
  end

  test "testing motor", %{floors: _floors} do
    assert Driver.set_motor_direction(:dir_down) == :ok
    assert wait_for_floor(Driver.get_floor_sensor_state()) != :between_floors
    assert Driver.set_motor_direction(:idle) == :ok
    assert Driver.get_floor_sensor_state() != :between_floors
  end
end
