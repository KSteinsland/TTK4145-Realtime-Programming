require Driver
require Elevator


defmodule FSM do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(opts \\ []) do
    state = {:elevator, :elevator_out}
    {:ok, state}
  end

  defp set_all_lights() do
    #Enum.each(Elevator.get_requests(Elevator), fn x -> Driver.set_order_button_light())
  end

  # User API ----------------------------------------------


  def on_init_between_floors(serverpid) do
    GenServer.cast(serverpid, :on_init_between_floors)
  end

  def on_request_button_press(serverpid, btn_floor, btn_type) do
    GenServer.cast(serverpid, {:on_request_button_press, btn_floor, btn_type})
  end

  # Casts  ----------------------------------------------

  def handle_cast({:on_init_betwwen_floors}, state) do
    {:elevator, :elevator_out} = state

    Driver.set_motor_direction(:down)
    Elevator.set_dir(Elevator, :down)
    Elevator.set_behaviour(Elevator, El_moving)

    {:noreply, state}

    # outputDevice.motorDirection(D_Down);
    # elevator.dirn = D_Down;
    # elevator.behaviour = EB_Moving;
  end


  def handle_cast({:on_request_button_press, btn_floor, btn_type}, state) do


    case Elevator.get_behaviour do
      :El_open ->
        if(Elevator.get_floor(Elevator) == btn_floor) do
          #timer_start(5) #seconds
        else
          Elevator.set_requests(btn_floor, btn_type, 1)
        end

      :El_moving ->
        Elevator.set_requests(btn_type, btn_type, 1)


      :El_idle ->
        if(Elevator.get_floor(Elevator) == btn_floor) do
          Driver.set_door_open_light(:on)
          #timer_start(5) #seconds
          Elevator.set_behaviour(Elevator, :El_door_open)
        else
          Elevator.set_requests(btn_floor, btn_type, 1)
          Requests.choose_direction(Elevator) |> Elevator.set_direction
        end

        _ ->
          {:noreply, state}
    end

    #{:noreply, state}

  end


  # Calls  ----------------------------------------------


end
