defmodule FSM do
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

  # def on_init_between_floors(%Elevator{} = elevator) do
  #   {:dir_down, %Elevator{elevator |
  #   direction: :dir_down,
  #   behaviour: :be_moving}}
  # end

  def on_request_button_press(%Elevator{} = elevator, btn_floor, btn_type) do
    case elevator.behaviour do
      :be_door_open ->
        if(elevator.floor == btn_floor) do
          {:start_timer, elevator}
        else
          {nil,
           %Elevator{elevator | requests: set_request(elevator.requests, btn_floor, btn_type, 1)}}
        end

      :be_moving ->
        {nil,
         %Elevator{elevator | requests: set_request(elevator.requests, btn_floor, btn_type, 1)}}

      :be_idle ->
        if(elevator.floor == btn_floor) do
          {:open_door, %Elevator{elevator | behaviour: :be_door_open}}
        else
          elevator = %Elevator{
            elevator
            | requests: set_request(elevator.requests, btn_floor, btn_type, 1)
          }

          elevator = %Elevator{
            elevator
            | direction: elevator |> Requests.choose_direction(),
              behaviour: :be_moving
          }

          {:move_elevator, elevator}
        end

      _ ->
        {nil, elevator}
    end
  end

  def on_floor_arrival(%Elevator{} = elevator, new_floor) do
    elevator = %Elevator{elevator | floor: new_floor}

    case elevator.behaviour do
      :be_moving ->
        if(Requests.should_stop?(elevator)) do
          elevator = elevator |> Requests.clear_at_current_floor()
          {:should_stop, %Elevator{elevator | behaviour: :be_door_open}}
        else
          {nil, elevator}
        end

      _ ->
        {nil, elevator}
    end
  end

  def on_door_timeout(%Elevator{} = elevator) do
    case elevator.behaviour do
      :be_door_open ->
        elevator = %Elevator{elevator | direction: elevator |> Requests.choose_direction()}

        if elevator.direction == :dir_stop do
          {:close_doors, %Elevator{elevator | behaviour: :be_idle}}
        else
          {:close_doors, %Elevator{elevator | behaviour: :be_moving}}
        end

      _ ->
        {nil, elevator}
    end
  end

  defp set_request(req, floor, btn_type, value) do
    {req_at_floor, _list} = List.pop_at(req, floor)
    updated_req_at_floor = List.replace_at(req_at_floor, @btn_types_map[btn_type], value)
    List.replace_at(req, floor, updated_req_at_floor)
  end
end
