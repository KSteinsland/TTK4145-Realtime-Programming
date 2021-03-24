defmodule FSM do
  @moduledoc """
  `FSM` is a pure module implementing the logic of an elevator as a finite state machine.
  """

  # def on_init_between_floors(%Elevator{} = elevator) do
  #   {:dir_down, %Elevator{elevator |
  #   direction: :dir_down,
  #   behaviour: :be_moving}}
  # end

  # TODO use Elevator.new function to check for errors!

  @spec on_request_button_press(Elevator.t(), pos_integer(), Elevator.btn_types()) ::
          {:move_elevator, Elevator.t()}
          | {nil, Elevator.t()}
          | {:open_door, Elevator.t()}
          | {:start_timer, Elevator.t()}
  @doc """
  Logic returning the required action to be done when a button is pressed
  and a new `Elevator` state.
  """
  def on_request_button_press(%Elevator{} = elevator, btn_floor, btn_type) do
    case elevator.behaviour do
      :be_door_open ->
        if(elevator.floor == btn_floor) do
          {:start_timer, elevator}
        else
          {nil,
           %Elevator{
             elevator
             | requests: Elevator.update_requests(elevator.requests, btn_floor, btn_type, 1)
           }}
        end

      :be_moving ->
        {nil,
         %Elevator{
           elevator
           | requests: Elevator.update_requests(elevator.requests, btn_floor, btn_type, 1)
         }}

      :be_idle ->
        if(elevator.floor == btn_floor) do
          {:open_door, %Elevator{elevator | behaviour: :be_door_open}}
        else
          elevator = %Elevator{
            elevator
            | requests: Elevator.update_requests(elevator.requests, btn_floor, btn_type, 1)
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

  @spec on_floor_arrival(Elevator.t(), pos_integer()) ::
          {nil, Elevator.t()} | {:stop, Elevator.t()}
  @doc """
  Logic returning the required action to be done when arriving at a floor
  and a new `Elevator` state.
  """
  def on_floor_arrival(%Elevator{} = elevator, new_floor) do
    elevator = %Elevator{elevator | floor: new_floor}

    case elevator.behaviour do
      :be_moving ->
        if(Requests.should_stop?(elevator)) do
          elevator = elevator |> Requests.clear_at_current_floor()
          {:stop, %Elevator{elevator | behaviour: :be_door_open}}
        else
          {nil, elevator}
        end

      _ ->
        {nil, elevator}
    end
  end

  @spec on_door_timeout(Elevator.t()) :: {:close_doors, Elevator.t()} | {nil, Elevator.t()}
  @doc """
  Logic returning the required action to be done when a door times out
  and a new `Elevator` state.
  """
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
end
