defmodule HardwarePoller do
  @moduledoc """
  Polling `GenServer` checking for changes and notifies
  """

  use GenServer


  require Logger

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @num_buttons length(@btn_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @input_poll_rate_ms Application.compile_env!(:elevator_project, :input_poll_rate_ms)


  @doc """
  Starts to process and registers its name to `ElevatorPoller`
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    IO.puts("Started hardware poller")

    # if Driver.get_floor_sensor_state() == :between_floors do
    #   # IO.puts("Between floors!")

    #   elevator =
    #     Elevator.check(%Elevator{
    #       SS.get_elevator(NodeConnector.get_self())
    #       | direction: :dir_down,
    #         behaviour: :be_moving
    #     })

    #   :ok = SS.set_elevator(NodeConnector.get_self(), elevator)

    #   Driver.set_motor_direction(:dir_down)
    # end

    req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = %{floor: 0, req_list: req_list, obstruction: :inactive}

    send(self(), :loop_poller)

    {:ok, state}
  end

  def handle_info(:poll_floor, state) do

    f = state.floor

    #if f != :between_floors && f != prev_floor do
    state = case Driver.get_floor_sensor_state() do
      ^f ->
        state

      new_floor ->
        IO.puts("Floor change!")
        %{floor: new_floor}
        #TODO notify

    end

    Process.send_after(self(), :loop_poller, @input_poll_rate_ms)

    {:noreply, state}

  end

  def handle_info(:poll_obstruction, state) do

    obs = state.obstruction

    # if Timer.has_timed_out() and Driver.get_obstruction_switch_state() == :inactive do
    #   Timer.timer_stop()
    #   :ok = SS.set_elevator(NodeConnector.get_self(), new_state)
    # end

    state = case Driver.get_obstruction_switch_state() do
      ^obs ->
        state

      new_obs ->
        IO.puts("Floor change!")
        %{obstruction: new_obs}
        #TODO notify
    end

    Process.send_after(self(), :loop_poller, @input_poll_rate_ms)

    {:noreply, state}

  end

  def handle_info(:poll_buttons, state) do

    req_list = check_requests(state.req_list)

    state = %{state | req_list: req_list}

    Process.send_after(self(), :loop_poller, @input_poll_rate_ms)

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

          #NOTFIY


        end

        v
      end)
    end)
  end
end
