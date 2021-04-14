defmodule StateServer do
  use GenServer

  defmodule HallRequests do
    @moduledoc """
      Hall Requests
    """

    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    # up down
    @num_hall_req_types 2

    @btn_map Application.fetch_env!(:elevator_project, :button_map)
    @hall_btn_map Map.drop(@btn_map, [:btn_cab])

    @btn_types Application.fetch_env!(:elevator_project, :button_types)
    @hall_btn_types List.delete(@btn_types, :btn_cab)

    @valid_hall_request_states [:new, :done]
    @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

    new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)

    defstruct hall_orders: new_hall_orders

    def update_hall_requests_logic(req, floor, btn_type, hall_state) do
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

  defmodule SystemState do
    @moduledoc """
      system state.
    """

    defstruct hall_requests: %HallRequests{}, elevators: %{}
  end

  def init(_opts) do
    wait_for_node_startup()

    # if NodeConnector.get_master() == NodeConnector.get_self() do
    {:ok, %SystemState{}}
    # else
    #   IO.puts("Received state from master")
    #   sys_state = GenServer.call({StateServer, NodeConnector.get_master()}, :get_state)
    #   {:ok, sys_state}
    # end
  end

  # client----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
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

  def set_elevator(node_name, elevator) do
    elevator = %Elevator{elevator | counter: elevator.counter + 1}
    GenServer.call(__MODULE__, {:set_elevator, node_name, elevator})
  end

  def set_state(new_state) do
    GenServer.cast(__MODULE__, {:set_state, new_state})
  end

  # def set_elevator_request(node_name, floor, btn_type) do
  #   GenServer.cast(__MODULE__, {:set_elevator_request, node_name, floor, btn_type})
  # end

  # def set_hall_requests(requests) do
  #  GenServer.cast(__MODULE__, {:set_hall_requests, requests})
  # end

  def update_hall_requests(floor_ind, btn_type, hall_state) do
    GenServer.cast(__MODULE__, {:update_hall_requests, floor_ind, btn_type, hall_state})
  end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get_elevator, node_name}, _from, state) do
    elevator_state = get_elevator_init(node_name, state.elevators)
    {:reply, elevator_state, state}
  end

  def handle_call(:get_hall_requests, _from, state) do
    {:reply, state.hall_requests, state}
  end

  def handle_call({:set_elevator, node_name, elevator}, _from, state) do
    case Elevator.check(elevator) do
      {:error, msg} ->
        {:reply, {:error, msg}, state}

      ^elevator ->
        if elevator.counter > get_elevator_init(node_name, state.elevators).counter do
          # sends new elevator state to master
          # master distributes it

          # async call to master to update everybody
          StateDistribution.new_elevator_state(NodeConnector.get_master(), node_name, elevator)

          new_state = %SystemState{
            state
            | elevators: Map.put(state.elevators, node_name, elevator)
          }

          {:reply, :ok, new_state}
        else
          # IO.puts("bad counter on set el!")
          {:reply, :ok, state}
        end
    end
  end

  # casts----------------------------------------

  def handle_cast({:set_elevator, node_name, elevator}, state) do
    if elevator.counter > get_elevator_init(node_name, state.elevators).counter do
      new_state = %SystemState{
        state
        | elevators: Map.put(state.elevators, node_name, elevator)
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:set_state, new_state}, _state) do
    {:noreply, new_state}
  end

  def handle_cast({:set_hall_requests, requests}, state) do
    new_state = %SystemState{state | hall_requests: requests}
    {:noreply, new_state}
  end

  def handle_cast({:update_hall_requests, floor_ind, btn_type, hall_state}, state) do
    hall_requests = state.hall_requests

    new_hall_requests =
      HallRequests.update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

    StateDistribution.update_hall_requests(
      NodeConnector.get_master(),
      NodeConnector.get_self(),
      floor_ind,
      btn_type,
      hall_state
    )

    state = %SystemState{state | hall_requests: new_hall_requests}
    {:noreply, state}
  end

  # def handle_cast({:set_elevator_request, node_name, floor, btn_type}, state) do
  #   elevator = get_elevator_init(node_name, state.elevators)

  #   new_elevator = %Elevator{
  #     elevator
  #     | requests: Elevator.update_requests(elevator.requests, floor, btn_type, 1)
  #   }

  #   new_state = %SystemState{state | elevators: Map.put(state.elevators, node_name, new_elevator)}

  #   StateDistribution.new_elevator_state(NodeConnector.get_master(), node_name, elevator)

  #   {:noreply, new_state}
  # end

  defp wait_for_node_startup() do
    if NodeConnector.get_master() == nil do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end

  defp get_elevator_init(node_name, elevators) do
    case Map.get(elevators, node_name) do
      nil ->
        %Elevator{}

      elevator_state ->
        elevator_state
    end
  end
end
