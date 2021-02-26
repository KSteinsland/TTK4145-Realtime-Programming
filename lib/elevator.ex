
defmodule Elevator do
    @moduledoc """
     Keeps Elevator state.
    """

    use GenServer

    @directions {:El_up, :El_down, :El_stop}
    @behaviours {:El_idle, :El_door_open, :El_moving}
    @button_tpyes {:hall_up, :hall_down, :cab}
    @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
    @num_floors 4
    @num_buttons 3

    req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)

    defstruct floor: 0, direction: :El_stop, requests: req_list, behaviour: :El_idle

    def init(_opts) do
        {:ok, %__MODULE__{}}
    end


    #API----------------------------------------
    def start_link() do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def get_floor() do
        GenServer.call __MODULE__, :get_floor
    end

    def get_direction() do
        GenServer.call __MODULE__, :get_direction
    end

    def get_requests() do
        GenServer.call __MODULE__, :get_requests
    end

    def get_behaviour() do
        GenServer.call __MODULE__, :get_behaviour
    end

    def set_floor(floor) do
        GenServer.cast __MODULE__, {:set_floor, floor}
    end

    def set_direction(direction) do
        GenServer.cast __MODULE__, {:set_direction, direction}
    end

    def set_request(floor, btn_type) do
        GenServer.cast __MODULE__, {:set_request, floor, btn_type}
    end

    def clear_request(floor, btn_type) do
        GenServer.cast __MODULE__, {:clear_request, floor, btn_type}
    end

    def set_behaviour(behaviour) do
        GenServer.cast __MODULE__, {:set_behaviour, behaviour}
    end

  
    #calls----------------------------------------
    def handle_call(:get_floor, _from, state) do
        {:reply, state.floor, state}
    end
   
    def handle_call(:get_direction, _from, state) do
        {:reply, state.direction, state}
    end

    def handle_call(:get_requests, _from, state) do
        {:reply, state.requests, state}
    end

    def handle_call(:get_requests, _from, state) do
        {:reply, state.requests, state}
    end

    def handle_call(:get_behaviour, _from, state) do
        {:reply, state.behaviour, state}
    end


    #casts----------------------------------------
    def handle_cast({:set_floor, floor}, state) do
        state = %{state | floor: floor}
        {:noreply, state}
    end

    def handle_cast({:set_direction, direction}, state) do
        state = %{state | direction: direction}
        {:noreply, state}
    end

    def handle_cast({:set_request, floor, btn_type}, state) do
        req = update_requests(state.requests, floor, btn_type, 1)
        state = %{state | requests: req}
        {:noreply, state}
    end

    def handle_cast({:clear_request, floor, btn_type}, state) do
        req = update_requests(state.requests, floor, btn_type, 0)
        state = %{state | requests: req}
        {:noreply, state}
    end

    def handle_cast({:set_behaviour, behaviour}, state) do
        state = %{state | behaviour: behaviour}
        {:noreply, state}
    end


    #util----------------------------------------
    defp update_requests(req, floor, btn_type, value) do 
        {req_at_floor, _list} = List.pop_at(req, floor)
        updated_req_at_floor = List.replace_at(req_at_floor, btn_type, value)
        req = List.replace_at(req, floor, updated_req_at_floor)
    end

end
