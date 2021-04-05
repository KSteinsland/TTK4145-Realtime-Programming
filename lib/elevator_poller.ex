defmodule ElevatorPoller do
  @moduledoc """
  Polling `GenServer` responsible driving a single elevator.
  """

  use GenServer

  alias StateInterface, as: ES

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @input_poll_rate_ms Application.compile_env!(:elevator_project, :input_poll_rate_ms)
  @door_open_duration_ms Application.compile_env!(:elevator_project, :door_open_duration_ms)

  @doc """
  Starts to process and registers its name to `ElevatorPoller`
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    IO.puts("Started!")

    if Driver.get_floor_sensor_state() == :between_floors do
      # IO.puts("Between floors!")
      Driver.set_motor_direction(:dir_down)

      elevator =
        Elevator.new(%Elevator{ES.get_state() | direction: :dir_down, behaviour: :be_moving})

      :ok = ES.set_state(elevator)
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
      state = ES.get_state()
      {action, new_state} = FSM.on_floor_arrival(state, f)

      Driver.set_floor_indicator(new_state.floor)

      case action do
        :stop ->
          set_all_hall_requests(new_state.requests, state.requests, new_state.floor)
          Driver.set_motor_direction(:dir_stop)
          Driver.set_door_open_light(:on)
          Timer.timer_start(@door_open_duration_ms)
          set_all_lights(new_state)

        _ ->
          :ok
      end

      :ok = ES.set_state(new_state)
    end

    prev_floor = f

    if Timer.has_timed_out() and Driver.get_obstruction_switch_state() == :inactive do
      # IO.puts("Door open timer has timed out!")
      {actions, new_state} = FSM.on_door_timeout(ES.get_state())

      case actions do
        :close_doors ->
          Driver.set_door_open_light(:off)
          new_state.direction |> Driver.set_motor_direction()

        _ ->
          :ok
      end

      Timer.timer_stop()
      :ok = ES.set_state(new_state)
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
          elevator = ES.get_state()

          {action, elevator} =
            FSM.on_request_button_press(elevator, floor_ind, Enum.at(@btn_types, btn_ind))

          case action do
            :start_timer ->
              # IO.puts("starting timer")
              Timer.timer_start(@door_open_duration_ms)

            :open_door ->
              # IO.puts("opening door!")
              Driver.set_door_open_light(:on)
              Timer.timer_start(@door_open_duration_ms)

            :move_elevator ->
              # IO.puts("setting motor direction")
              elevator.direction |> Driver.set_motor_direction()

              # move elevator should only trigger on cab requests once we have state distribution fixed!
              # TODO remove this when state distributor is finished
              if btn_ind < 2 do
                ES.new_hall_request(floor_ind, Enum.at(@btn_types, btn_ind))
              end

            :update_hall_requests ->
              IO.puts("New hall request!")
              ES.new_hall_request(floor_ind, Enum.at(@hall_btn_types, btn_ind))

            nil ->
              :ok
          end

          set_all_lights(elevator)
          :ok = ES.set_state(elevator)
        end

        v
      end)
    end)
  end

  defp set_all_lights(elevator) do
    light_state = [:off, :on]

    Enum.with_index(elevator.requests)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.zip(floor, @btn_types)
      |> Enum.map(fn {btn, btn_type} ->
        Driver.set_order_button_light(btn_type, floor_ind, Enum.at(light_state, btn))
      end)
    end)
  end

  # defp hall_request_at_current_floor?(floor_ind, requests) do
  #   requests
  #   |> Enum.at(floor_ind)
  #   |> Enum.any?(fn req -> req in @hall_btn_types end)
  # end

  defp set_all_hall_requests(req_list, prev_req_list, floor_ind) do
    # Sets all hall requests which are executed in system state

    Enum.zip(Enum.at(req_list, floor_ind), Enum.at(prev_req_list, floor_ind))
    |> Enum.with_index()
    |> Enum.map(fn {{btn, btn_old}, btn_ind} ->
      btn_type = Enum.at(@btn_types, btn_ind)

      if btn != btn_old and btn_type in @hall_btn_types do
        ES.finished_hall_request(floor_ind, btn_type)
      end
    end)
  end
end
