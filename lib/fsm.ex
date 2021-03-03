require Driver
require Elevator
require Requests
require Timer

defmodule FSM do
  use GenServer
  #use Agent probably enough

  #########
  # all Request functions should receive which elevator it is handling, to allow for easy expansion to multiple elevators

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__, debug: [:trace]])
  end

  def init(_opts \\ []) do
    {:ok, {}}
  end

  defp set_all_lights() do

    #order_types = Map.keys(Elevator.button_map)
    btn_types = [:cab, :hall_down, :hall_up]

    for {floor, floor_ind} <- Enum.with_index(Elevator.get_requests()) do
      for {btn, btn_ind} <- Enum.with_index(floor) do
        if (btn == 1) do
          Driver.set_order_button_light(Enum.at(btn_types, btn_ind), floor_ind, :on)
        else
          Driver.set_order_button_light(Enum.at(btn_types, btn_ind), floor_ind, :off)
        end
      end
    end
  end

  # User API ----------------------------------------------


  def on_init_between_floors() do
    GenServer.call(__MODULE__, {:on_init_between_floors})
  end

  def on_request_button_press(btn_floor, btn_type) do
    GenServer.call(__MODULE__, {:on_request_button_press, btn_floor, btn_type})
  end

  def on_floor_arrival(new_floor) do
    GenServer.call(__MODULE__, {:on_floor_arrival, new_floor})
  end

  def on_door_timeout() do
    GenServer.call(__MODULE__, {:on_door_timeout})
  end

  # Casts  ----------------------------------------------


  # Calls  ----------------------------------------------

  def handle_call({:on_init_between_floors}, _from, state) do

    IO.inspect("between floors")
    Driver.set_motor_direction(:El_down)
    Elevator.set_direction(:El_down)
    Elevator.set_behaviour(:El_moving)

    {:reply, :ok, state}

  end


  def handle_call({:on_request_button_press, btn_floor, btn_type}, _from, state) do


    case Elevator.get_behaviour do
      :El_door_open ->
        if(Elevator.get_floor() == btn_floor) do
          Timer.timer_start(5_000) #seconds
        else
          Elevator.set_request(btn_floor, btn_type)
        end

      :El_moving ->
        Elevator.set_request(btn_floor, btn_type)


      :El_idle ->
        if(Elevator.get_floor() == btn_floor) do
          Driver.set_door_open_light(:on)
          Timer.timer_start(5_000) #seconds
          Elevator.set_behaviour(:El_door_open)
        else
          Elevator.set_request(btn_floor, btn_type)
          Requests.choose_direction() |> Elevator.set_direction()
          Elevator.get_direction |> Driver.set_motor_direction()
          Elevator.set_behaviour(:El_moving)
        end

        _ ->
          :ok
          # {:reply, :ok, state}
    end

    set_all_lights()

    # IS TIHS OKAY?
    {:reply, :ok,  state}

  end

  def handle_call({:on_floor_arrival, new_floor}, _from, state) do

    Elevator.set_floor(new_floor)

    IO.inspect("At a new floor")

    Elevator.get_floor |> Driver.set_floor_indicator

    case Elevator.get_behaviour do
      :El_moving ->
        if(Requests.should_stop?()) do

          Driver.set_motor_direction(:El_stop)
          Driver.set_door_open_light(:on)
          Requests.clear_at_current_floor()
          Timer.timer_start(3_000) # (elevator.config.door_open_duration_s)
          set_all_lights()
          Elevator.set_behaviour(:El_door_open)

        end

      _ ->
        :ok

    end

    {:reply, :ok, state}

  end


  def handle_call({:on_door_timeout},  _from, state) do

    case Elevator.get_behaviour() do
      :El_door_open ->
        Requests.choose_direction() |> Elevator.set_direction()

        Driver.set_door_open_light(:off)
        Elevator.get_direction() |> Driver.set_motor_direction()

        if (Elevator.get_direction() == :El_stop) do
          Elevator.set_behaviour(:El_idle)
        else
          Elevator.set_behaviour(:El_moving)
        end

      _ ->
        :ok
    end

    {:reply, :ok, state}

  end

end
