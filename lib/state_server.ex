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

    if NodeConnector.get_master == Node.self do
      {:ok, %SystemState{}}
    else
      IO.puts("Received state from master")
      sys_state = GenServer.call({StateServer, NodeConnector.get_master}, :get_state)
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

  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, state) do
    # Checks that all elevator states are valid before accecpting the new state
    # Could use some fixing
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

  defp wait_for_node_startup() do
    if NodeConnector.get_master == nil do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end

end
