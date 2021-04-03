defmodule StateInterface do
  @moduledoc """
    Operates on the local elevator state
  """

  @btn_map Application.fetch_env!(:elevator_project, :button_map)
  @hall_btn_map Map.drop(@btn_map, [:btn_cab])
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)
  @valid_hall_request_states [:new, :done]

  alias StateServer, as: SS

  @doc """
  returns elevator state on this node in system state
  """
  def get_state do
    wait_for_node_startup()

    if Map.has_key?(SS.get_state().elevators, NodeConnector.get_state().name()) do
      SS.get_state().elevators
      |> Map.get(NodeConnector.get_state().name())
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

    # if (NodeConnector.get_state.name() == :nonode@nohost) do
    #   IO.puts("Node is not started yet!")
    # else
    # end

    #elevator = %{elevator | count: elevator.count + 1}

    case Elevator.new(elevator) do
      {:error, msg} ->
        {:error, msg}

      ^elevator ->
        # sys_state = SS.get_state()
        # elevators_new = Map.put(sys_state.elevators, NodeConnector.get_state().name(), elevator)
        # sys_state = %{sys_state | elevators: elevators_new}
        # GenServer.multi_call(SS, {:set_state, sys_state}) # push

        {m, _bs} = GenServer.multi_call(StateServer, :get_state) #pull everyones state
        sys_state =  Map.get(Map.new(m), NodeConnector.get_state().name() ) #extract my system state
        elevators_old = sys_state.elevators 
        elevators_new = Enum.map(m, fn {k, v} -> {k, v.elevators[k]} end)#update my state with everyone elses, need to do for each put map
          |> Enum.reduce(elevators_old, fn {k, v}, els -> Map.put(els, k, v) end)
          |> Map.put(NodeConnector.get_state().name(), elevator) #add new elevator
        sys_state = %{sys_state | elevators: elevators_new} #add to system state 
        GenServer.multi_call(SS, {:set_state, sys_state}) # push


        :ok
    end
  end

  def finished_hall_request(floor_ind, btn_type) do
    sys_state = SS.get_state()

    new_hall_requests = update_hall_requests(sys_state.hall_requests, floor_ind, btn_type, :done)

    SS.set_state(%{sys_state | hall_requests: new_hall_requests})
  end

  def new_hall_request(floor_ind, btn_type) do
    sys_state = SS.get_state()

    new_hall_requests = update_hall_requests(sys_state.hall_requests, floor_ind, btn_type, :new)

    SS.set_state(%{sys_state | hall_requests: new_hall_requests})
  end

  defp wait_for_node_startup() do
    # is this ok?
    # Ensures that we do not register :nonode@nohost in the elevator map
    if NodeConnector.get_state().name() == :nonode@nohost do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end

  defp update_hall_requests(req, floor, btn_type, state) do
    # TODO make this a config maybe?
    # valid_buttons = [0, 1]
    # also check floor and btn_type beforehand!

    req_list = req.hall_orders

    if state in @valid_hall_request_states and btn_type in @hall_btn_types do
      {req_at_floor, _list} = List.pop_at(req_list, floor)
      updated_req_at_floor = List.replace_at(req_at_floor, @hall_btn_map[btn_type], state)
      new_req_list = List.replace_at(req_list, floor, updated_req_at_floor)
      %StateServer.HallRequests{req | hall_orders: new_req_list}
    else
      {:error, "not valid hall request state!"}
    end
  end
end
