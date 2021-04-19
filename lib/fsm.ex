defmodule FSM do
  @moduledoc """
  `FSM` is a pure module implementing the logic of an elevator as a finite state machine.
  """

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @spec on_init_between_floors(Elevator.t(), Elevator.floor()) ::
          {:move_down, Elevator.t()} | {nil, Elevator.t()}
  @doc """
  Logic returning the required action to be done when the elevator is initialized.
  """
  def on_init_between_floors(%Elevator{} = elevator, floor) do
    case floor do
      :between_floors ->
        {:move_down, %Elevator{elevator | direction: :dir_down, behaviour: :be_moving}}

      floor ->
        {nil, %Elevator{elevator | floor: floor}}
    end
  end

  @spec on_request(Elevator.t(), Elevator.floor(), Elevator.btn_type(), :button | :message) ::
          {:move_elevator, Elevator.t()}
          | {nil, Elevator.t()}
          | {:open_door, Elevator.t()}
          | {:start_timer, Elevator.t()}
          | {:update_hall_requests, Elevator.t()}
  @doc """
  Logic returning the required action to be done when a button is pressed
  and a new `Elevator` state.
  """
  # TODO make this return actions = {action, nil | :new | :done}
  def on_request(%Elevator{} = elevator, btn_floor, btn_type, req_type) do
    # maybe we should send update_hall_requests, even if elevator.floor = btn_floor
    # to make the best elevator take the order
    if req_type == :button and btn_type in @hall_btn_types do
      case elevator.behaviour do
        :be_door_open ->
          if(elevator.floor == btn_floor) do
            {:start_timer, elevator}
          else
            {:update_hall_requests, elevator}
          end

        :be_moving ->
          {:update_hall_requests, elevator}

        :be_idle ->
          if(elevator.floor == btn_floor) do
            {:open_door, %Elevator{elevator | behaviour: :be_door_open}}
          else
            {:update_hall_requests, elevator}
          end

        _ ->
          {nil, elevator}
      end
    else
      case elevator.behaviour do
        :be_door_open ->
          if(elevator.floor == btn_floor) do
            {:start_timer, elevator}
          else
            new_elevator = %Elevator{
              elevator
              | requests: Elevator.update_requests(elevator.requests, btn_floor, btn_type, 1)
            }

            {nil, new_elevator}
          end

        :be_moving ->
          new_elevator = %Elevator{
            elevator
            | requests: Elevator.update_requests(elevator.requests, btn_floor, btn_type, 1)
          }

          {nil, new_elevator}

        :be_idle ->
          if(elevator.floor == btn_floor) do
            {:open_door, %Elevator{elevator | behaviour: :be_door_open}}
          else
            elevator = %Elevator{
              elevator
              | requests: Elevator.update_requests(elevator.requests, btn_floor, btn_type, 1)
            }

            new_elevator = %Elevator{
              elevator
              | direction: elevator |> Requests.choose_direction(),
                behaviour: :be_moving
            }

            {:move_elevator, new_elevator}
          end

        _ ->
          {nil, elevator}
      end
    end
  end

  @spec on_floor_arrival(Elevator.t(), Elevator.floor()) ::
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
        if not elevator.obstructed do
          elevator = %Elevator{elevator | direction: elevator |> Requests.choose_direction()}

          if elevator.direction == :dir_stop do
            {:close_doors, %Elevator{elevator | behaviour: :be_idle}}
          else
            {:close_doors, %Elevator{elevator | behaviour: :be_moving}}
          end
        else
          {nil, elevator}
        end

      _ ->
        {nil, elevator}
    end
  end

  @spec on_obstruction_change(Elevator.t(), :active | :inactive) ::
          {:start_timer, Elevator.t()} | {nil, Elevator.t()}
  @doc """
  Logic returning the required action to be done when the obstruction state changes
  and a new `Elevator` state.
  """
  def on_obstruction_change(%Elevator{} = elevator, obs_state) do
    case elevator.behaviour do
      :be_door_open ->
        if obs_state == :inactive do
          {:start_timer, %Elevator{elevator | obstructed: false}}
        else
          {nil, %Elevator{elevator | obstructed: true}}
        end

      _ ->
        if obs_state == :inactive do
          {nil, %Elevator{elevator | obstructed: false}}
        else
          {nil, %Elevator{elevator | obstructed: true}}
        end
    end
  end
end
