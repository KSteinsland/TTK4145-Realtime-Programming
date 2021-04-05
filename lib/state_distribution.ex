defmodule StateDistribution do
  use GenServer

  @moduledoc """
    Handles distribution of state in the case of both master and slave status
  """

  @btn_map Application.fetch_env!(:elevator_project, :button_map)
  @hall_btn_map Map.drop(@btn_map, [:btn_cab])
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)
  @valid_hall_request_states [:new, :done]
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

  alias StateServer, as: SS

  # client----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def get_state(node_name) do
    # TODO make this a call...
    elevator_state = SS.get_elevator(node_name)

    if elevator_state != nil do
      elevator_state
    else
      # set_state(%Elevator{})

      %Elevator{}
    end
  end

  def set_state(%Elevator{} = elevator) do
    # do Elevator.new check first?

    # sends new elevator state to master
    # master checks if state is distributes it
    GenServer.call(
      {__MODULE__, NodeConnector.get_master()},
      {:new_state, NodeConnector.get_self(), elevator}
    )
  end

  def set_hall_request(hall_state, floor_ind, btn_type) do
    # hall_requests = SS.get_hall_requests()
    # new_hall_requests = update_hall_requests(hall_requests, floor_ind, btn_type, state)
    # SS.set_hall_requests(new_hall_requests)

    GenServer.call(
      {__MODULE__, NodeConnector.get_master()},
      {:update_hall_requests, floor_ind, btn_type, hall_state}
    )
  end

  def handle_call({:new_state, node_name, elevator}, _from, state) do
    # just to be sure
    if NodeConnector.get_role() == :master do
      # check if we have a local copy, if not, make one
      local_copy = SS.get_elevator(node_name)

      local_copy =
        case local_copy do
          nil ->
            %Elevator{}

          _ ->
            local_copy
        end

      elevator =
        cond do
          elevator.counter <= local_copy.counter ->
            IO.puts("Old counter!")

            %Elevator{
              elevator
              | requests: update_cab_requests(elevator, local_copy),
                counter: local_copy.counter + 1
            }

          true ->
            elevator
        end

      # IO.inspect(elevator)

      # send new elevator to all slaves
      # NB! should we send every elevator state here? or just the elevator that has been changed?

      {m, _bs} = GenServer.multi_call(StateServer, {:set_elevator, node_name, elevator})
      # IO.puts("distributing state")
      # not sure if we should call StateDistribution on all nodes which again calls stateserver
      # or call stateserver directly on all nodes

      {:reply, :ok, state}
    else
      # possible solution
      # SS.set_elevator(elevator)

      # currently not in use
      {:reply, :error, state}
    end
  end

  def handle_call({:update_hall_requests, floor_ind, btn_type, hall_state}, _from, state) do
    # either drop role check and multicall StateServer as we currently do
    # or use role check and multicall THIS call and then call stateserver

    if NodeConnector.get_role() == :master do
      hall_requests = SS.get_hall_requests()
      new_hall_requests = update_hall_requests(hall_requests, floor_ind, btn_type, hall_state)

      # TODO check state!
      # if state == :new do something
      # else if state == :done do something else

      {m, _bs} = GenServer.multi_call(StateServer, {:set_hall_requests, new_hall_requests})
      # not sure if we should call StateDistribution on all nodes which again calls stateserver
      # or call stateserver directly on all nodes

      {:reply, :ok, state}
    else
      # possible solution?
      # SS.set_hall_requests(new_hall_requests)
      #

      # currently not in use
      {:reply, :error, state}
    end
  end

  defp update_cab_requests(elevator, latest_elevator) do
    ## Adds all cab requests from latest_elevator to elevators requests
    new_requests =
      latest_elevator.requests
      |> Enum.with_index()
      |> Enum.reduce(elevator.requests, fn {floor, floor_ind}, acc ->
        val = Enum.at(floor, Map.get(@btn_types_map, :btn_cab))

        if val == 1 do
          Elevator.update_requests(
            acc,
            floor_ind,
            :btn_cab,
            val
          )
        else
          acc
        end
      end)

    new_requests
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
