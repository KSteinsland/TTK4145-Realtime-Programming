defmodule ElevatorPoller do
  use GenServer

  alias Elevator.StateServer, as: ES

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)

  @input_poll_rate_ms 25
  @door_open_duration_ms 3_000
  @stop_duration_ms 5_000

  def start_link([]) do
    # , debug: [:trace]])
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    IO.puts("Started!")

    if Driver.get_floor_sensor_state() == :between_floors do
      IO.puts("Between floors!")
      Driver.set_motor_direction(:dir_down)
      elevator = Elevator.new(ES.get_state(), %{direction: :dir_down, behaviour: :be_moving})
      ES.set_state(elevator)
    end

    prev_floor = 0
    prev_req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = {prev_floor, prev_req_list}

    send(self(), :loop_poller)

    {:ok, state}
  end

  def handle_info(:loop_poller, state) do
    {prev_floor, prev_req_list} = state

    prev_req_list = check_requests(prev_req_list)

    f = Driver.get_floor_sensor_state()

    if f != :between_floors && f != prev_floor do
      IO.puts("Arrived at floor!")
      {action, new_state} = FSM.on_floor_arrival(ES.get_state(), f)

      Driver.set_floor_indicator(new_state.floor)

      case action do
        :should_stop ->
          Driver.set_motor_direction(:dir_stop)
          Driver.set_door_open_light(:on)
          Timer.timer_start(@door_open_duration_ms)
          set_all_lights(new_state)

        _ ->
          :ok
      end

      ES.set_state(new_state)
    end

    prev_floor = f

    if(Timer.has_timed_out()) do
      IO.puts("Door open timer has timed out!")
      {actions, new_state} = FSM.on_door_timeout(ES.get_state())

      case actions do
        :close_doors ->
          Driver.set_door_open_light(:off)
          new_state.direction |> Driver.set_motor_direction()

        _ ->
          :ok
      end

      Timer.timer_stop()
      ES.set_state(new_state)
    end

    Process.send_after(self(), :loop_poller, @input_poll_rate_ms)

    state = {prev_floor, prev_req_list}
    {:noreply, state}
  end

  defp check_requests(prev_req_list) do
    Enum.with_index(prev_req_list)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {_btn, btn_ind} ->
        v = Driver.get_order_button_state(floor_ind, Enum.at(@btn_types, btn_ind))

        prev_v = prev_req_list |> Enum.at(floor_ind) |> Enum.at(btn_ind)

        if v == 1 && v != prev_v do
          # this needs cleanup by theo
          elevator = ES.get_state()

          {action, elevator} =
            FSM.on_request_button_press(elevator, floor_ind, Enum.at(@btn_types, btn_ind))

          case action do
            :start_timer ->
              IO.puts("starting timer")
              Timer.timer_start(@stop_duration_ms)

            :open_door ->
              IO.puts("opening door!")
              Driver.set_door_open_light(:on)
              Timer.timer_start(@stop_duration_ms)

            :move_elevator ->
              IO.puts("setting motor direction")
              IO.inspect(elevator.direction)
              elevator.direction |> Driver.set_motor_direction()

            nil ->
              :ok
          end

          set_all_lights(elevator)
          ES.set_state(elevator)
        end

        v
      end)
    end)
  end

  defp set_all_lights(elevator) do
    Enum.with_index(elevator.requests)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {btn, btn_ind} ->
        if btn == 1 do
          Driver.set_order_button_light(Enum.at(@btn_types, btn_ind), floor_ind, :on)
        else
          Driver.set_order_button_light(Enum.at(@btn_types, btn_ind), floor_ind, :off)
        end
      end)
    end)
  end
end
