defmodule ElevatorPollerTest do
  use ExUnit.Case, async: false
  doctest ElevatorPoller
  @moduletag :external

  defp wait_for_behaviour(behaviour) do
    if StateInterface.get_state().behaviour == behaviour do
      :ok
    else
      wait_for_behaviour(behaviour)
    end
  end

  defp wait_for_direction(direction) do
    if StateInterface.get_state().direction == direction do
      :ok
    else
      wait_for_direction(direction)
    end
  end

  # defp wait_for_floor(floor_n) do
  #   if Driver.get_floor_sensor_state() == floor_n do
  #     # Driver.set_motor_direction(:dir_stop)
  #     floor_n
  #   else
  #     wait_for_floor(floor_n)
  #   end
  # end

  defp wait_for_floor(floor_n) do
    if StateInterface.get_state().floor == floor_n do
      floor_n
    else
      wait_for_floor(floor_n)
    end
  end

  # defp move_to_floor(floor_n) do
  #   if Driver.get_floor_sensor_state() == floor_n do
  #     Driver.set_motor_direction(:dir_stop)
  #     floor_n
  #   else
  #     Driver.set_motor_direction(:dir_down)
  #     wait_for_floor(floor_n)
  #   end
  # end

  defp setup_bottom_floor(context) do
    Process.whereis(StateServer) |> Process.exit(:kill)
    Process.sleep(500)
    # move_to_floor(0)
    Simulator.send_key("q")
    wait_for_floor(0)
    :ok
  end

  defp setup_top_floor(context) do
    Process.whereis(StateServer) |> Process.exit(:kill)
    Process.sleep(500)
    # move_to_floor(3)
    Simulator.send_key("r")
    wait_for_floor(3)
    :ok
  end

  def setup_app(context) do
    ElevatorProject.Application.start(nil, nil)
    Process.sleep(1_000)
    :ok
  end

  setup_all do
    # Ensure that the application is started
    # ElevatorProject.Application.start(nil, nil)
    # Process.sleep(1_000)

    # Optionally only ensure that the processes needed are started
    # port = Application.fetch_env!(:elevator_project, :port_driver)]
    # Driver.start_link([{127, 0, 0, 1}, port])
    # Elevator.start_link([])

    on_exit(&cleanup/0)


    # Put elevator in a repeatable state
    # move_to_floor(0)
    IO.puts("Setup finished")

    %{top_floor: Application.fetch_env!(:elevator_project, :num_floors) - 1}
  end

  describe "continues along current direction, bottom to top" do
    setup [:setup_app, :setup_bottom_floor]

    test "bottom to top", context do
      IO.puts("bottom to top")
      Simulator.send_key("f")
      Simulator.send_key("d")
      Simulator.send_key("s")

      wait_for_floor(context.top_floor)
      wait_for_behaviour(:be_door_open)

      assert StateInterface.get_state().floor == context.top_floor
    end
  end

  describe "continues along current direction, top to bottom" do
    setup [:setup_app, :setup_top_floor]

    test "top to bottom", _context do
      IO.puts("top to bottom")
      Simulator.send_key("z")

      wait_for_floor(0)
      wait_for_behaviour(:be_door_open)

      assert StateInterface.get_state().floor == 0
    end
  end


  defp cleanup() do
    Supervisor.stop(ElevatorProject.Supervisor, :normal)
  end

end
