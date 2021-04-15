defmodule ElevatorPoller do
  @moduledoc """
  Polling `GenServer` responsible driving a single elevator.
  """

  use GenServer

  alias StateServer, as: SS

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

      elevator =
        Elevator.check(%Elevator{
          SS.get_elevator(NodeConnector.get_self())
          | direction: :dir_down,
            behaviour: :be_moving
        })

      :ok = SS.set_elevator(NodeConnector.get_self(), elevator)

      Driver.set_motor_direction(:dir_down)
    end

    prev_floor = 0
    prev_req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = {prev_floor, prev_req_list}

    send(self(), :loop_poller)

    {:ok, state}
  end

  @spec send_hall_request(node(), Elevator.floors(), Elevator.hall_btn_types()) :: :ok
  @doc """
  Sends a assigned hall request to the elevator at `node_name` to be executed
  """
  def send_hall_request(node_name, floor_ind, btn_type) do
    GenServer.cast(
      {__MODULE__, node_name},
      {:assigned_hall_request, floor_ind, btn_type}
    )
  end

  def handle_cast({:assigned_hall_request, floor_ind, btn_type}, state) do
    elevator = SS.get_elevator(NodeConnector.get_self())

    elevator = request_procedure(elevator, floor_ind, btn_type, :message)

    :ok = SS.set_elevator(NodeConnector.get_self(), elevator)

    {:noreply, state}
  end

  def handle_info(:loop_poller, state) do
    # Internal polling loop

    {prev_floor, prev_req_list} = state

    prev_req_list = check_requests(prev_req_list)

    f = Driver.get_floor_sensor_state()

    if f != :between_floors && f != prev_floor do
      IO.puts("Arrived at floor!")
      state = SS.get_elevator(NodeConnector.get_self())
      {action, new_state} = FSM.on_floor_arrival(state, f)

      Driver.set_floor_indicator(new_state.floor)

      case action do
        :stop ->
          set_all_hall_requests(new_state.requests, state.requests, new_state.floor)
          Driver.set_motor_direction(:dir_stop)
          Driver.set_door_open_light(:on)
          Timer.timer_start(@door_open_duration_ms)
          set_all_cab_lights(new_state)

        _ ->
          :ok
      end

      :ok = SS.set_elevator(NodeConnector.get_self(), new_state)
    end

    prev_floor = f

    if Timer.has_timed_out() and Driver.get_obstruction_switch_state() == :inactive do
      # IO.puts("Door open timer has timed out!")
      {actions, new_state} = FSM.on_door_timeout(SS.get_elevator(NodeConnector.get_self()))

      case actions do
        :close_doors ->
          Driver.set_door_open_light(:off)
          new_state.direction |> Driver.set_motor_direction()

        _ ->
          :ok
      end

      Timer.timer_stop()
      :ok = SS.set_elevator(NodeConnector.get_self(), new_state)
    end

    Process.send_after(self(), :loop_poller, @input_poll_rate_ms)

    state = {prev_floor, prev_req_list}
    {:noreply, state}
  end

  defp check_requests(prev_req_list) do
    # Iterates through all num_floors x buttons and checks for button press

    Enum.with_index(prev_req_list)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {_btn, btn_ind} ->
        btn_type = @btn_types |> Enum.at(btn_ind)

        v = Driver.get_order_button_state(floor_ind, btn_type)

        prev_v = prev_req_list |> Enum.at(floor_ind) |> Enum.at(btn_ind)

        if v == 1 && v != prev_v do
          elevator = SS.get_elevator(NodeConnector.get_self())

          elevator = request_procedure(elevator, floor_ind, btn_type, :button)

          :ok = SS.set_elevator(NodeConnector.get_self(), elevator)
        end

        v
      end)
    end)
  end

  defp request_procedure(elevator, floor, btn_type, req_type) do
    # performs actions on received request, either a request button press
    # or a request message from distribution

    {action, elevator} = FSM.on_request(elevator, floor, btn_type, req_type)
    # IO.inspect(action)

    case action do
      :start_timer ->
        IO.puts("starting timer")
        Timer.timer_start(@door_open_duration_ms)
        if req_type == :message, do: SS.update_hall_requests(floor, btn_type, :done)

      :open_door ->
        IO.puts("opening door!")
        Driver.set_door_open_light(:on)
        Timer.timer_start(@door_open_duration_ms)
        if req_type == :message, do: SS.update_hall_requests(floor, btn_type, :done)

      :move_elevator ->
        IO.puts("setting motor direction")
        elevator.direction |> Driver.set_motor_direction()

      :update_hall_requests ->
        IO.puts("New hall request!")
        SS.update_hall_requests(floor, btn_type, :new)

      nil ->
        :ok
    end

    set_all_cab_lights(elevator)
    elevator
  end

  defp set_all_cab_lights(elevator) do
    light_state = [:off, :on]

    Enum.with_index(elevator.requests)
    |> Enum.map(fn {floor, floor_ind} ->
      cab_btn = Enum.at(floor, 2)
      Driver.set_order_button_light(:btn_cab, floor_ind, Enum.at(light_state, cab_btn))
    end)
  end

  defp set_all_hall_requests(req_list, prev_req_list, floor_ind) do
    # Sets all hall requests which are executed in state

    Enum.zip(Enum.at(req_list, floor_ind), Enum.at(prev_req_list, floor_ind))
    |> Enum.with_index()
    |> Enum.map(fn {{btn, btn_old}, btn_ind} ->
      btn_type = Enum.at(@btn_types, btn_ind)

      if btn != btn_old and btn_type in @hall_btn_types do
        # IO.puts("updating hall requests!")
        SS.update_hall_requests(floor_ind, btn_type, :done)
      end
    end)
  end
end
