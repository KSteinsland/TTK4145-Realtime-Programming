
defmodule Elevator do
    @moduledoc """
     Keeps Elevator state.
    """
    use GenServer

    defstruct floor: 0, direction: :El_stop, requests: [], behaviour: :El_idle

    def init(_opts) do
        {:ok, %__MODULE__{}}
    end


    #API----------------------------------------
    def start_link() do
        GenServer.start_link(__MODULE__, [])
    end
    
    
    def get_floor(pid) do
        GenServer.call pid, :get_floor
    end

    def get_direction(pid) do
        GenServer.call pid, :get_direction
    end

    def get_requests(pid) do
        GenServer.call pid, :get_requests
    end

    def get_behaviour(pid) do
        GenServer.call pid, :get_behaviour
    end


    def set_floor(pid, floor) do
        GenServer.cast pid, {:set_floor, floor}
    end

    def set_direction(pid, direction) do
        GenServer.cast pid, {:set_direction, direction}
    end

    def set_requests(pid, requests) do
        GenServer.cast pid, {:set_requests, requests}
    end

    def set_behaviour(pid, behaviour) do
        GenServer.cast pid, {:set_behaviour, behaviour}
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

    def handle_cast({:set_requests, requests}, state) do
        state = %{state | requests: requests}
        {:noreply, state}
    end

    def handle_cast({:set_behaviour, behaviour}, state) do
        state = %{state | behaviour: behaviour}
        {:noreply, state}
    end
end
