require Driver
require FSM
#require Timer

defmodule ElevatorPoller do

  #THIS needs fixing
  @num_floors 4
  @num_buttons 3
  @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}

  def start_loop() do
    IO.puts("Started!")

    input_poll_rate_ms = 25

    if (Driver.get_floor_sensor_state() == :between_floors) do
      FSM.on_init_between_floors()
    end


    prev_floor = 0
    prev_req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)
    state = {prev_floor, prev_req_list, input_poll_rate_ms}
    poll_loop(state)
  end

  defp check_requests(prev_req_list) do

    for floor_ind <- 0..@num_floors-1 do
      for button_ind <- 0..@num_buttons-1 do

        v = Driver.get_order_button_state(floor_ind, button_ind)

        prev_v = Enum.at(prev_req_list, floor_ind) |> Enum.at(button_ind)

        if (v && v != prev_v) do
          FSM.on_request_button_press(floor_ind, button_ind)
        end

        update_list(prev_req_list, floor_ind, button_ind, v)
      end
    end
  end



  defp poll_loop(state) do

    {prev_floor, prev_req_list, input_poll_rate_ms} = state

    prev_req_list = check_requests(prev_req_list)

    f = Driver.get_floor_sensor_state()

    if (f != :between_floors && f != prev_floor) do
      FSM.on_floor_arrival(f)
    end

    prev_floor = f

    if(Timer.timed_out) do
      FSM.on_door_timeout()
      Timer.stop()
    end

    Process.sleep(input_poll_rate_ms)

    state = {prev_floor, prev_req_list, input_poll_rate_ms}
    poll_loop(state)
  end

  #util----------------------------------------
  defp update_list(req, floor, btn_type, value) do
    {req_at_floor, _list} = List.pop_at(req, floor)
    updated_req_at_floor = List.replace_at(req_at_floor, btn_type, value)
    req = List.replace_at(req, floor, updated_req_at_floor)
  end

end
