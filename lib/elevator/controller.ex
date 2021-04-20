defmodule Elevator.Controller do
  @moduledoc """
  `GenServer` responsible driving a single elevator.
  """

  use GenServer

  alias StateServer, as: SS
  alias Elevator.Hardware.Driver
  alias Elevator.Timer
  alias Elevator.FSM

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @door_open_duration_ms Application.compile_env!(:elevator_project, :door_open_duration_ms)
  @move_timeout_ms Application.compile_env!(:elevator_project, :move_timeout_ms)

  @doc """
  Starts to process and registers its name to `ElevatorController`
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec send_request(node(), Elevator.floor(), Elevator.hall_btn_type()) ::
          :ok
  @doc """
  Sends a assigned hall request to the elevator at `node_name`.
  `req_type` determines action
  """
  def send_request(node_name, floor_ind, btn_type) do
    GenServer.cast(
      {__MODULE__, node_name},
      {:send_request, floor_ind, btn_type}
    )
  end

  @spec init_controller(Elevator.floor()) :: :ok
  def init_controller(floor) do
    GenServer.cast(
      __MODULE__,
      {:init_controller, floor}
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
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:init_controller, floor}, _state) do
    {action, new_elevator} = FSM.on_init_between_floors(SS.get_elevator(node()), floor)

    case action do
      :move ->
        new_elevator.direction |> Driver.set_motor_direction()
        Timer.timer_start(self(), @move_timeout_ms, :move)

        if new_elevator.floor != :between_floors,
          do: Driver.set_floor_indicator(new_elevator.floor)

      _ ->
        Driver.set_floor_indicator(new_elevator.floor)
    end

    Driver.set_door_open_light(:off)

    set_all_cab_lights(new_elevator)

    :ok = SS.set_elevator(node(), new_elevator)

    {:noreply, %{}}
  end

  @impl true
  def handle_cast({:send_request, floor, btn_type}, _state) do
    {action, new_elevator} = FSM.on_request(SS.get_elevator(node()), floor, btn_type)

    case action do
      :start_timer ->
        Timer.timer_start(self(), @door_open_duration_ms, :door)

        if btn_type in @hall_btn_types do
          SS.update_hall_requests(floor, btn_type, :done)
          RequestHandler.new_state()
        end

      :open_door ->
        Driver.set_door_open_light(:on)
        Timer.timer_start(self(), @door_open_duration_ms, :door)

        if btn_type in @hall_btn_types do
          SS.update_hall_requests(floor, btn_type, :done)
          RequestHandler.new_state()
        end

      :move_elevator ->
        new_elevator.direction |> Driver.set_motor_direction()
        Timer.timer_start(self(), @move_timeout_ms, :move)

      nil ->
        :ok
    end

    set_all_cab_lights(new_elevator)

    :ok = SS.set_elevator(node(), new_elevator)

    {:noreply, %{}}
  end

  @impl true
  def handle_cast({:floor_change, floor}, _state) do
    if floor != :between_floors do
      elevator = SS.get_elevator(node())
      {action, new_elevator} = FSM.on_floor_arrival(elevator, floor)

      Driver.set_floor_indicator(new_elevator.floor)
      Timer.timer_stop(:move)

      case action do
        :stop ->
          set_all_hall_requests(new_elevator.requests, elevator.requests, new_elevator.floor)
          Driver.set_motor_direction(:dir_stop)
          Driver.set_door_open_light(:on)
          Timer.timer_start(self(), @door_open_duration_ms, :door)
          set_all_cab_lights(new_elevator)

        _ ->
          if new_elevator.direction != :dir_stop do
            new_elevator.direction |> Driver.set_motor_direction()
            Timer.timer_start(self(), @move_timeout_ms, :move)
          else
            Driver.set_motor_direction(:dir_stop)
          end
      end

      SS.node_active(node(), not new_elevator.obstructed)
      :ok = SS.set_elevator(node(), new_elevator)
    end

    {:noreply, %{}}
  end

  @impl true
  def handle_cast({:obstruction_change, obs_state}, _state) do
    {action, new_elevator} = FSM.on_obstruction_change(SS.get_elevator(node()), obs_state)

    case action do
      :start_timer ->
        Timer.timer_start(self(), @door_open_duration_ms, :door)
        set_all_cab_lights(new_elevator)

      _ ->
        :ok
    end

    :ok = SS.set_elevator(node(), new_elevator)

    SS.node_active(node(), not new_elevator.obstructed)

    {:noreply, %{}}
  end

  @impl true
  def handle_info({:timed_out, :door}, _state) do
    {action, new_elevator} = FSM.on_door_timeout(SS.get_elevator(node()))

    case action do
      :close_doors ->
        Driver.set_door_open_light(:off)
        new_elevator.direction |> Driver.set_motor_direction()

        if new_elevator.direction != :dir_stop,
          do: Timer.timer_start(self(), @move_timeout_ms, :move)

      _ ->
        :ok
    end

    Timer.timer_stop(:door)
    :ok = SS.set_elevator(node(), new_elevator)

    {:noreply, %{}}
  end

  @impl true
  def handle_info({:timed_out, :move}, _state) do
    elevator = SS.get_elevator(node())
    SS.node_active(node(), false)
    if elevator.behaviour == :be_moving, do: throw(:error)

    {:noreply, %{}}
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
        SS.update_hall_requests(floor_ind, btn_type, :done)
        RequestHandler.new_state()
      end
    end)
  end
end
