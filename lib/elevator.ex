
defmodule Elevator do
    use GenServer

    defstruct floor: 0, direction: :El_stop, requests: [], behaviour: :El_idle


    def start_link() do
        GenServer.start_link(__MODULE__, [])
    end
    

    def get_floor(pid) do
        GenServer.call pid, :get_floor
    end


    def init(_opts) do
        {:ok, %__MODULE__{}}
    end
    
    def handle_call(:get_floor, _from, state) do
        {:reply, state.floor, state}
    end
end
