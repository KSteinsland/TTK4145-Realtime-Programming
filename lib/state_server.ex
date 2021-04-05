defmodule StateServer do
  use GenServer

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

  def init(_opts) do
    wait_for_node_startup()

    if NodeConnector.get_master() == NodeConnector.get_self() do
      {:ok, %SystemState{}}
    else
      IO.puts("Received state from master")
      sys_state = GenServer.call({StateServer, NodeConnector.get_master()}, :get_state)
      {:ok, sys_state}
    end
  end

  # client----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
    # , debug: [:trace])
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_elevator(node_name) do
    GenServer.call(__MODULE__, {:get_elevator, node_name})
  end

  def get_hall_requests() do
    GenServer.call(__MODULE__, :get_hall_requests)
  end

  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  def set_elevator(node_name, elevator) do
    GenServer.call(__MODULE__, {:set_elevator, node_name, elevator})
  end

  def set_hall_requests(requests) do
    GenServer.call(__MODULE__, {:set_hall_requests, requests})
  end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, state) do
    # Checks that all elevator states are valid before accecpting the new state
    # Could use some fixing

    # TODO check that every counter is larger than in the state.elevators?

    valid =
      new_state.elevators
      |> Map.values()
      |> Enum.all?(fn elevator ->
        elevator == Elevator.new(elevator)
      end)

    if valid do
      {:reply, :ok, new_state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:get_elevator, node_name}, _from, state) do
    {:reply, Map.get(state.elevators, node_name), state}
  end

  def handle_call(:get_hall_requests, _from, state) do
    # TODO this needs fxing
    {:reply, state.hall_requests, state}
  end

  def handle_call({:set_elevator, node_name, elevator}, _from, state) do
    new_state = %SystemState{
      state
      | elevators: Map.put(state.elevators, node_name, elevator)
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:set_hall_requests, requests}, _from, state) do
    # TODO this needs fixing
    new_state = %SystemState{state | hall_requests: requests}
    {:reply, :ok, new_state}
  end

  defp wait_for_node_startup() do
    if NodeConnector.get_master() == nil do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end
end
