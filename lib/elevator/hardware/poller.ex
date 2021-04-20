defmodule Elevator.Hardware.Poller do
  @moduledoc """
  Polling `GenServer` checking for changes,
  notifies `Elevator.Controller`.
  """

  use GenServer

  alias Elevator.Hardware.Driver

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons length(@btn_types)

  @floor_poll_rate_ms Application.compile_env!(:elevator_project, :floor_poll_rate_ms)
  @obs_poll_rate_ms Application.compile_env!(:elevator_project, :obs_poll_rate_ms)
  @buttons_poll_rate_ms Application.compile_env!(:elevator_project, :buttons_poll_rate_ms)

  @doc """
  Starts to process and registers its name to `HardwarePoller`
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    IO.puts("Started hardware poller")

    req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = %{floor: nil, req_list: req_list, obstruction: nil, initialized: false}

    send(self(), :poll_floor)
    send(self(), :poll_obstruction)
    send(self(), :poll_buttons)

    {:ok, state}
  end

  def handle_info(:poll_floor, state) do
    f = state.floor

    state =
      case Driver.get_floor_sensor_state() do
        ^f ->
          state

        new_floor ->
          if not state.initialized do
            # Tell controller to init
            Elevator.Controller.init_controller(new_floor)
            %{state | floor: new_floor, initialized: true}
          else
            Elevator.Controller.floor_change(new_floor)
            %{state | floor: new_floor}
          end
      end

    Process.send_after(self(), :poll_floor, @floor_poll_rate_ms)

    {:noreply, state}
  end

  def handle_info(:poll_obstruction, state) do
    obs = state.obstruction

    state =
      case Driver.get_obstruction_switch_state() do
        ^obs ->
          state

        new_obs ->
          Elevator.Controller.obstruction_change(new_obs)
          %{state | obstruction: new_obs}
      end

    Process.send_after(self(), :poll_obstruction, @obs_poll_rate_ms)

    {:noreply, state}
  end

  def handle_info(:poll_buttons, state) do
    # Iterates through all num_floors x buttons and checks for button presses
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
            if btn_type in @hall_btn_types do
              # IO.puts("New hall request!")
              StateServer.update_hall_requests(floor_ind, btn_type, :new)
              RequestHandler.new_state()
            else
              # Cab order
              Elevator.Controller.send_request(node(), floor_ind, btn_type)
            end
          end

          v
        end)
      end)

    state = %{state | req_list: req_list}

    Process.send_after(self(), :poll_buttons, @buttons_poll_rate_ms)

    {:noreply, state}
  end
end
