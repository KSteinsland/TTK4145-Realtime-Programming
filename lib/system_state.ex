defmodule HallRequests do
  @moduledoc """
    Hall Requests
  """

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  # up down
  @num_hall_req_types 2

  new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)

  defstruct hall_orders: new_hall_orders
end

defmodule SystemState do
  @moduledoc """
    system state.
  """

  defstruct hall_requests: %HallRequests{}, elevators: %{}
end

defmodule StateInterface do
  @moduledoc """
    Operates on the local elevator state
  """

  alias StateServer, as: SS

  @doc """
  returns elevator state on this node in system state
  """
  def get_state do
    wait_for_node_startup()

    if Map.has_key?(SS.get_state().elevators, Node.self()) do
      SS.get_state().elevators
      |> Map.get(Node.self())
    else
      set_state(%Elevator{})

      %Elevator{}
    end
  end

  @doc """
  sets elevator state on this node in system state
  """
  def set_state(%Elevator{} = elevator) do
    wait_for_node_startup()

    # alternative to wait_for_node_startup

    # if (Node.self() == :nonode@nohost) do
    #   IO.puts("Node is not started yet!")
    # else
    # end

    case Elevator.new(elevator) do
      {:error, msg} ->
        {:error, msg}

      ^elevator ->
        sys_state = SS.get_state()

        elevators_new = Map.put(sys_state.elevators, Node.self(), elevator)

        SS.set_state(%{sys_state | elevators: elevators_new})
    end
  end

  defp wait_for_node_startup() do
    # is this ok?
    # Ensures that we do not register :nonode@nohost in the elevator map
    if Node.self() == :nonode@nohost do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end
end
