defmodule StateServer do
  use GenServer

  @btn_map Application.fetch_env!(:elevator_project, :button_map)
  @hall_btn_map Map.drop(@btn_map, [:btn_cab])

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  @valid_hall_request_states [:new, :done]
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)


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

  def update_hall_requests(floor_ind, btn_type, hall_state) do
    GenServer.call(__MODULE__, {:update_hall_requests, floor_ind, btn_type, hall_state})
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
    elevator_state =
    case Map.get(state.elevators, node_name) do
      nil ->
        %Elevator{}

      elevator_state ->
        elevator_state
    end
    {:reply, elevator_state, state}
  end

  def handle_call(:get_hall_requests, _from, state) do
    {:reply, state.hall_requests, state}
  end

  def handle_call({:set_elevator, node_name, elevator}, _from, state) do

    case Elevator.new(elevator) do
      {:error, msg} ->
        {:reply,  {:error, msg}, state}

      ^elevator ->
        elevator = %Elevator{elevator | counter: elevator.counter + 1}

        # sends new elevator state to master
        # master checks if state is ok and distributes it

        # async call to master to update everybody
        GenServer.cast(
          {StateDistribution, NodeConnector.get_master()},
          :new_state
        )

        new_state = %SystemState{
          state
          | elevators: Map.put(state.elevators, node_name, elevator)
        }

        {:reply, :ok, new_state}

    end
  end

  def handle_call({:set_hall_requests, requests}, _from, state) do
    # TODO this needs fixing
    new_state = %SystemState{state | hall_requests: requests}
    {:reply, :ok, new_state}
  end

  def handle_call({:update_hall_requests, floor_ind, btn_type, hall_state}, _from, state) do

    hall_requests = state.hall_requests
    new_hall_requests = update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)


    # and make it a function in statedist
    GenServer.cast(
      {StateDistribution, NodeConnector.get_master()},
      {:update_hall_requests, new_hall_requests}
    )

    state = %SystemState{state | hall_requests: new_hall_requests}
    {:reply, :ok, state}

  end

  defp wait_for_node_startup() do
    if NodeConnector.get_master() == nil do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end

  defp update_hall_requests_logic(req, floor, btn_type, hall_state) do
    # TODO make this a config maybe?
    # valid_buttons = [0, 1]
    # also check floor and btn_type beforehand!

    req_list = req.hall_orders

    if hall_state in @valid_hall_request_states and btn_type in @hall_btn_types do

      {req_at_floor, _list} = List.pop_at(req_list, floor)
      updated_req_at_floor = List.replace_at(req_at_floor, @hall_btn_map[btn_type], hall_state)
      new_req_list = List.replace_at(req_list, floor, updated_req_at_floor)
      %StateServer.HallRequests{req | hall_orders: new_req_list}
    else
      {:error, "not valid hall request state!"}
    end
  end

end
