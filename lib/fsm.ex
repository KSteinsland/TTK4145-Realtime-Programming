require Driver
require Elevator
#require Requests
#require Timer

defmodule FSM do
  use GenServer
  #use Agent probably enough

  #########
  # all Request functions should receive which elevator it is handling, to allow for easy expansion to multiple elevators

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts \\ []) do
    {:ok, {}}
  end

  defp set_all_lights() do
    #Enum.each(Elevator.get_requests(Elevator), fn x -> Driver.set_order_button_light())
  end

  # User API ----------------------------------------------


  def on_init_between_floors(serverpid) do
    GenServer.cast(serverpid, {:on_init_between_floors})
  end

  def on_request_button_press(serverpid, btn_floor, btn_type) do
    GenServer.cast(serverpid, {:on_request_button_press, btn_floor, btn_type})
  end

  def on_floor_arrival(serverpid, new_floor) do
    GenServer.cast(serverpid, {:on_floor_arrival, new_floor})
  end

  # Casts  ----------------------------------------------

  def handle_cast({:on_init_between_floors}, state) do

    IO.inspect("between floors")
    Driver.set_motor_direction(:down)
    Elevator.set_direction(:down)
    Elevator.set_behaviour(:El_moving)

    {:noreply, state}

  end


  def handle_cast({:on_request_button_press, btn_floor, btn_type}, state) do


    case Elevator.get_behaviour do
      :El_open ->
        if(Elevator.get_floor() == btn_floor) do
          #timer_start(5) #seconds
        else
          Elevator.set_requests(btn_floor, btn_type, 1)
        end

      :El_moving ->
        Elevator.set_requests(btn_type, btn_type, 1)


      :El_idle ->
        if(Elevator.get_floor() == btn_floor) do
          Driver.set_door_open_light(:on)
          #timer_start(5) #seconds
          Elevator.set_behaviour(:El_door_open)
        else
          Elevator.set_requests(btn_floor, btn_type, 1)
          Requests.choose_direction() |> Elevator.set_direction
        end

        _ ->
          {:noreply, state}
    end

    # IS TIHS OKAY?
    {:noreply, state}

  end

  def handle_cast({:on_floor_arrival, new_floor}, state) do

    Elevator.set_floor(new_floor)

    Elevator.get_floor |> Driver.set_floor_indicator

    case Elevator.get_behaviour do
      :El_moving ->
        if(Requests.shouldStop) do
          Driver.set_motor_direction(:stop)
          Driver.set_door_open_light(:on)
          #elevator = Request.clear_at_current_floor()
          #Timer.start(elevator.config.door_open_duration_s)
          set_all_lights()
          Elevator.set_behaviour(:El_door_open)
        end
    end

    {:noreply, state}

  end


  def handle_cast({:on_door_timeout}, state) do

    case Elevator.get_behaviour do
      El_door_open ->
        Request.choose_direction |> Elevator.set_direction

        Driver.set_door_open_light(0)
        Elevator.get_direction |> Driver.set_motor_direction

        if (Elevator.get_direction == :D_stop) do
          Elevator.set_behaviour(:El_idle)
        else
          Elevator.set_behaviour(:El_moving)
        end
    end

    {:noreply, state}

  end


  # Calls  ----------------------------------------------


end
