defmodule HallRequests do
    @moduledoc """
      Hall Requests
    """

    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    @num_hall_req_types 2 #up down

    new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)

    defstruct hall_orders: new_hall_orders 

end


defmodule SystemState do
    @moduledoc """
      system state.
    """

    defstruct hall_requests: %HallRequests{}, elevators: %{el1: %Elevator{}}


    
end

defmodule StateInterface do
    @moduledoc """
      Operates on the local elevator state
    """


    @doc """
    returns elevator state on this node in system state
    """
    def get_state do 
        Elevator.StateServer.get_state().elevators |> Map.get(:el1) #should be Node.self not :el1
    end

    @doc """
    sets elevator state on this node in system state
    """    
    def set_state(%Elevator{} = elevator) do
        sys_state = Elevator.StateServer.get_state()

        elevators_new = %{sys_state.elevators | :el1 => elevator}

        Elevator.StateServer.set_state(%{sys_state | elevators: elevators_new})
    end

end