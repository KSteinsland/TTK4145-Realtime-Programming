require Driver
require FSM
require Timer

defmodule ElevatorPoller do
  use GenServer

  #THIS needs fixing
  @num_floors 4
  @num_buttons 3
  @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}


  def start_link([]) do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__]) #, debug: [:trace]])
  end


  def init([]) do

    IO.puts("Started!")

    input_poll_rate_ms = 25

    if (Driver.get_floor_sensor_state() == :between_floors) do
      IO.puts("Between floors!")
      FSM.on_init_between_floors()
    end


    prev_floor = 0
    prev_req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = {prev_floor, prev_req_list, input_poll_rate_ms}

    send(self(), :loop_poller)

    {:ok, state}
  end

  def handle_info(:loop_poller, state) do


    {prev_floor, prev_req_list, input_poll_rate_ms} = state

    prev_req_list = check_requests(prev_req_list)

    f = Driver.get_floor_sensor_state()

    if (f != :between_floors && f != prev_floor) do
      IO.puts("Arrived at floor!")
      FSM.on_floor_arrival(f)
    end

    prev_floor = f

    if(Timer.has_timed_out()) do
      IO.puts("Door open timer has timed out!")
      FSM.on_door_timeout()
      Timer.timer_stop()
    end

    #Process.sleep(input_poll_rate_ms)
    Process.send_after(self(), :loop_poller, input_poll_rate_ms)

    state = {prev_floor, prev_req_list, input_poll_rate_ms}
    {:noreply, state}

  end

  def check_requests(prev_req_list) do

    btn_types = [:cab, :hall_down, :hall_up]

    for {floor, floor_ind} <- Enum.with_index(prev_req_list) do
      for {_button, button_ind} <- Enum.with_index(floor) do

        v = Driver.get_order_button_state(floor_ind, Enum.at(btn_types, button_ind))

        prev_v = prev_req_list |> Enum.at(floor_ind) |> Enum.at(button_ind)

        if (v==1 && v != prev_v) do
          FSM.on_request_button_press(floor_ind, button_ind)
        end

        v

      end
    end
  end

end
