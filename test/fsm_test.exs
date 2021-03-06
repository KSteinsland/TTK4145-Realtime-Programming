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
    if (Driver.get_floor_sensor_state == floor_n) do
      floor_n
    else
      wait_for_floor(floor_n)
    end
  end

  setup_all do
      port = 17777

      {:ok, elevator_driver_pid} = Driver.start_link([{127,0,0,1}, port])
      {:ok, elevator_pid} = Elevator.start_link([])

      %{pid: elevator_pid}
  end

  test "just arrived at a floor", %{pid: _pid} do
    Elevator.set_floor(2)
    Elevator.set_behaviour(:be_moving)

    assert Driver.set_motor_direction(:dir_down) == :ok
    new_floor = wait_for_floor(0)
    assert FSM.on_floor_arrival(new_floor) == :ok

    assert Elevator.get_floor == new_floor
    assert Driver.get_floor_sensor_state == new_floor
    assert Elevator.get_behaviour() == :be_door_open

    IO.puts("testing init")
  end

end
