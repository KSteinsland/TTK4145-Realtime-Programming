defmodule ElevatorController do
  @moduledoc """
  `GenServer` responsible driving a single elevator.
  """

  # TODO remove horrible init state!!!!!!

  use GenServer

  alias StateServer, as: SS
  require Logger

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @door_open_duration_ms Application.compile_env!(:elevator_project, :door_open_duration_ms)

  @doc """
  Starts to process and registers its name to `ElevatorController`
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec send_hall_request(node(), Elevator.floor(), Elevator.hall_btn_type(), :button | :message) ::
          :ok
  @doc """
  Sends a assigned hall request to the elevator at `node_name`.
  `req_type` determines action
  """
  def send_hall_request(node_name, floor_ind, btn_type, req_type) do
    GenServer.cast(
      {__MODULE__, node_name},
      {:assigned_hall_request, floor_ind, btn_type, req_type}
    )
  end

  @spec floor_change(Elevator.floor() | :between_floors) :: :ok
  @doc """
  Sends a floor change message
  """
  def floor_change(floor) do
    GenServer.cast(
      __MODULE__,
      {:floor_change, floor}
    )
  end

  @spec obstruction_change(:active | :inactive) :: :ok
  @doc """
  Sends a obstruction message
  """
  def obstruction_change(obs_state) do
    GenServer.cast(
      __MODULE__,
      {:obstruction_change, obs_state}
    )
  end

  @impl true
  def init([]) do
    IO.puts("Started!")
    state = %{initialized: false}
    {:ok, state}
  end

  @impl true
  def handle_cast({:assigned_hall_request, floor, btn_type, req_type}, state) do
    if state.initialized do
      elevator = SS.get_elevator(Node.self())

      # performs actions on received request, either a request button press
      # or a request message from distribution

      {action, elevator} = FSM.on_request(elevator, floor, btn_type, req_type)
      # IO.inspect(action)

      # TODO move req_type check into FSM and return a list of actions instead
      case action do
        :start_timer ->
          IO.puts("starting timer")
          Timer.timer_start(self(), @door_open_duration_ms)

          if req_type == :message do
            SS.update_hall_requests(floor, btn_type, :done)
            RequestHandler.new_state()
          end

        :open_door ->
          IO.puts("opening door!")
          Driver.set_door_open_light(:on)
          Timer.timer_start(self(), @door_open_duration_ms)

          if req_type == :message do
            SS.update_hall_requests(floor, btn_type, :done)
            RequestHandler.new_state()
          end

        :move_elevator ->
          Logger.debug("setting motor direction")
          # IO.puts("setting motor direction")
          elevator.direction |> Driver.set_motor_direction()

        :update_hall_requests ->
          IO.puts("New hall request!")
          SS.update_hall_requests(floor, btn_type, :new)
          RequestHandler.new_state()

        nil ->
          :ok
      end

      set_all_cab_lights(elevator)

      :ok = SS.set_elevator(Node.self(), elevator)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:floor_change, floor}, state) do
    if not state.initialized do
      IO.puts("initializing elevator!")

      if floor == :between_floors do
        # IO.puts("Between floors!")

        {:ok, elevator} =
          Elevator.check(%Elevator{
            SS.get_elevator(Node.self())
            | direction: :dir_down,
              behaviour: :be_moving
          })

        :ok = SS.set_elevator(Node.self(), elevator)

        Driver.set_motor_direction(:dir_down)
      else
        {:ok, elevator} =
          Elevator.check(%Elevator{
            SS.get_elevator(Node.self())
            | floor: floor
          })

        :ok = SS.set_elevator(Node.self(), elevator)
      end

      {:noreply, %{state | initialized: true}}
    else
      if floor != :between_floors do
        IO.puts("Arrived at floor!")
        state = SS.get_elevator(Node.self())
        {action, new_state} = FSM.on_floor_arrival(state, floor)

        Driver.set_floor_indicator(new_state.floor)

        case action do
          :stop ->
            set_all_hall_requests(new_state.requests, state.requests, new_state.floor)
            Driver.set_motor_direction(:dir_stop)
            Driver.set_door_open_light(:on)
            Timer.timer_start(self(), @door_open_duration_ms)
            set_all_cab_lights(new_state)

          _ ->
            :ok
        end

        :ok = SS.set_elevator(Node.self(), new_state)
      end

      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:obstruction_change, obs_state}, state) do
    if state.initialized do
      obs =
        case obs_state do
          :active ->
            true

          :inactive ->
            false
        end

      elevator = %Elevator{SS.get_elevator(Node.self()) | obstructed: obs}
      :ok = SS.set_elevator(Node.self(), elevator)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:timed_out, state) do
    if state.initialized do
      elevator = SS.get_elevator(Node.self())

      if not elevator.obstructed do
        # IO.puts("Door open timer has timed out!")
        {action, new_elevator} = FSM.on_door_timeout(elevator)

        case action do
          :close_doors ->
            Driver.set_door_open_light(:off)
            new_elevator.direction |> Driver.set_motor_direction()

          _ ->
            :ok
        end

        Timer.timer_stop()
        :ok = SS.set_elevator(Node.self(), new_elevator)
      end

      {:noreply, state}
    else
      {:noreply, state}
    end
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
