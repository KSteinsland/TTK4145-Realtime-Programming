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
    GenServer.start_link(__MODULE__, [], [name: __MODULE__, debug: [:trace]])
  end


  def init([]) do

    IO.puts("Started!")

    input_poll_rate_ms = 500#25

    if (Driver.get_floor_sensor_state() == :between_floors) do
      FSM.on_init_between_floors()
    end


    prev_floor = 0
    prev_req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = {prev_floor, prev_req_list, input_poll_rate_ms}

    send(self(), :loop_poller)

    {:ok, state}
  end

  def handle_info(:loop_poller, state) do

    IO.puts("Looping!")

    {prev_floor, prev_req_list, input_poll_rate_ms} = state

    prev_req_list = check_requests(prev_req_list)

    f = Driver.get_floor_sensor_state()

    if (f != :between_floors && f != prev_floor) do
      FSM.on_floor_arrival(f)
    end

    prev_floor = f

    if(Timer.has_timed_out) do
      FSM.on_door_timeout()
      Timer.timer_stop()
    end

    #Process.sleep(input_poll_rate_ms)
    Process.send_after(self(), :loop_poller, input_poll_rate_ms)

    state = {prev_floor, prev_req_list, input_poll_rate_ms}
    {:noreply, state}

  end

  # defp loop_buttons(floor, prev_floor, floor_ind, button_ind) do

  #   btn_types = [:cab, :hall_down, :hall_up]

  #   v = Driver.get_order_button_state(floor_ind, Enum.at(btn_types, button_ind))
  #   IO.inspect v

  #   prev_v = Enum.at(prev_floor, button_ind)
  #   IO.inspect prev_v

  #   if (v && v != prev_v) do
  #     FSM.on_request_button_press(floor_ind, button_ind)
  #   end

  #   floor  =  List.replace_at(prev_floor, Enum.at(btn_types, button_ind), v)
  #   #= update_list(prev_req_list, floor_ind, button_ind, v)
  #   IO.inspect floor

  #   if button_ind < @num_buttons-1 do
  #     loop_buttons(floor, prev_floor, floor_ind, button_ind+1)
  #   else
  #     {floor, prev_floor, floor_ind, button_ind}
  #   end
  # end

  # def check_requests_old(prev_req_list) do

  #   btn_types = [:cab, :hall_down, :hall_up]

  #   tmp_list = for floor_ind <- 0..@num_floors-1 do
  #     tmp_list =for button_ind <- 0..@num_buttons-1 do


  #       v = Driver.get_order_button_state(floor_ind, Enum.at(btn_types, button_ind))
  #       IO.inspect v

  #       prev_v = Enum.at(prev_req_list, floor_ind) |> Enum.at(button_ind)
  #       IO.inspect prev_v

  #       if (v && v != prev_v) do
  #         FSM.on_request_button_press(floor_ind, button_ind)
  #       end

  #       tmp_list = update_list(prev_req_list, floor_ind, button_ind, v)
  #       IO.inspect tmp_list
  #       tmp_list
  #     end
  #     IO.inspect tmp_list
  #   end
  #   IO.inspect tmp_list
  # end

  # def check_requests_old2(prev_req_list) do
  #   for floor_ind <- 0..@num_floors-1 do
  #     {tmp_list, _, _, _} = loop_buttons(nil, Enum.at(prev_req_list, floor_ind), floor_ind, 0)
  #     IO.inspect(tmp_list)
  #     prev_req_list = List.replace_at(prev_req_list, floor_ind, tmp_list)
  #   end
  # end

  def check_requests(prev_req_list) do

    btn_types = [:cab, :hall_down, :hall_up]

    for {floor, floor_ind} <- Enum.with_index(prev_req_list) do
      for {_button, button_ind} <- Enum.with_index(floor) do

        v = Driver.get_order_button_state(floor_ind, Enum.at(btn_types, button_ind))

        IO.inspect(v, [label: "Driver button state"])

        prev_v = prev_req_list |> Enum.at(floor_ind) |> Enum.at(button_ind)
        IO.inspect(prev_v, [label: "Prev button state"])

        if (v && v != prev_v) do
          FSM.on_request_button_press(floor_ind, button_ind)
        end

        #tmp_list = update_list(prev_req_list, floor_ind, button_ind, v)
        v

      end
    end
  end


  #util----------------------------------------
  # def update_list(req, floor, btn_type, value) do
  #   {req_at_floor, _list} = List.pop_at(req, floor)
  #   updated_req_at_floor = List.replace_at(req_at_floor, btn_type, value)
  #   List.replace_at(req, floor, updated_req_at_floor)
  # end

end
