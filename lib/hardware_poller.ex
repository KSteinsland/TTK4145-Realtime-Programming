defmodule HardwarePoller do
  @moduledoc """
  Polling `GenServer` checking for changes and notifies
  """

  use GenServer

  require Logger

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @num_buttons length(@btn_types)

  # @input_poll_rate_ms Application.compile_env!(:elevator_project, :input_poll_rate_ms)
  @floor_poll_rate_ms 50
  @obs_poll_rate_ms 50
  @buttons_poll_rate_ms 25

  @doc """
  Starts to process and registers its name to `HardwarePoller`
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    IO.puts("Started hardware poller")

    req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = %{floor: nil, req_list: req_list, obstruction: nil}

    send(self(), :poll_floor)
    send(self(), :poll_obstruction)
    send(self(), :poll_buttons)

    {:ok, state}
  end

  def handle_info(:poll_floor, state) do
    f = state.floor

    # if f != :between_floors && f != prev_floor do
    state =
      case Driver.get_floor_sensor_state() do
        ^f ->
          state

        new_floor ->
          IO.puts("Floor change!")
          ElevatorController.floor_change(new_floor)
          %{state | floor: new_floor}
      end

    Process.send_after(self(), :poll_floor, @floor_poll_rate_ms)

    {:noreply, state}
  end

  def handle_info(:poll_obstruction, state) do
    obs = state.obstruction

    # if Timer.has_timed_out() and Driver.get_obstruction_switch_state() == :inactive do
    #   Timer.timer_stop()
    #   :ok = SS.set_elevator(Node.self(), new_state)
    # end

    state =
      case Driver.get_obstruction_switch_state() do
        ^obs ->
          state

        new_obs ->
          IO.puts("Obstruction change!")
          ElevatorController.obstruction_change(new_obs)
          %{state | obstruction: new_obs}
      end

    Process.send_after(self(), :poll_obstruction, @obs_poll_rate_ms)

    {:noreply, state}
  end

  def handle_info(:poll_buttons, state) do
    # Iterates through all num_floors x buttons and checks for button press
    prev_req_list = state.req_list

    req_list =
      Enum.with_index(prev_req_list)
      |> Enum.map(fn {floor, floor_ind} ->
        Enum.with_index(floor)
        |> Enum.map(fn {_btn, btn_ind} ->
          btn_type = @btn_types |> Enum.at(btn_ind)

          v = Driver.get_order_button_state(floor_ind, btn_type)

          prev_v = prev_req_list |> Enum.at(floor_ind) |> Enum.at(btn_ind)

          if v == 1 && v != prev_v do
            ElevatorController.send_hall_request(Node.self(), floor_ind, btn_type, :button)
          end

          v
        end)
      end)

    state = %{state | req_list: req_list}

    Process.send_after(self(), :poll_buttons, @buttons_poll_rate_ms)

    {:noreply, state}
  end
end
