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

  defp get_state() do
    NodeConnector.wait_for_node_startup()
    GenServer.call(__MODULE__, :get_state)
  end

  # def set_state(%Elevator{} = elevator) do
  #   NodeConnector.wait_for_node_startup()

  #   case Elevator.new(elevator) do
  #     {:error, msg} ->
  #       {:error, msg}

  #     ^elevator ->
  #       elevator = %Elevator{elevator | counter: elevator.counter + 1}

  #       # sends new elevator state to master
  #       # master checks if state is ok and distributes it

  #       # set local state to ensure proper elevator_poller behaviour
  #       SS.set_elevator(NodeConnector.get_self(), elevator)

  #       # async call to master to update everybody
  #       GenServer.cast(
  #         {__MODULE__, NodeConnector.get_master()},
  #         {:new_state, NodeConnector.get_self(), elevator}
  #       )

  #       :ok
  #   end
  # end

  # def set_hall_request(floor_ind, btn_type, hall_state) do
  #   # check if state is :done or :new
  #   # :assigned is not valid
  #   GenServer.call(
  #     {__MODULE__, NodeConnector.get_master()},
  #     {:update_hall_requests, floor_ind, btn_type, hall_state}
  #   )
  # end

  # calls ----------------------------------------

  def handle_call(:get_state, _from, state) do
    elevator_state = SS.get_elevator(NodeConnector.get_self())
    {:reply, elevator_state, state}
  end


  def handle_cast({:update_hall_requests, new_hall_requests}, state) do
    if NodeConnector.get_role() == :master do

      # TODO check state!
      # if state == :new do something
      # else if state == :done do something else

      IO.puts("here!")

      {_m, _bs} = GenServer.multi_call(Node.list(), StateServer, {:set_hall_requests, new_hall_requests}, 400)

      {:noreply, state}
    else
      # currently not in use
      {:noreply, state}
    end
  end

  # casts ----------------------------------------

  def handle_cast(:new_state, state) do
    if NodeConnector.get_role() == :master do
      # # check if we have a local copy, if not, make one
      # local_copy =
      #   case SS.get_elevator(node_name) do
      #     nil ->
      #       %Elevator{}

      #     local_copy ->
      #       local_copy
      #   end

      # # check if elevatorstate is outdated, probably not needed...
      # elevator =
      #   cond do
      #     elevator.counter <= local_copy.counter and node_name != NodeConnector.get_self() ->
      #       IO.puts("Old counter!")

      #       %Elevator{
      #         elevator
      #         | requests: update_cab_requests(elevator, local_copy),
      #           counter: local_copy.counter + 1
      #       }

      #     true ->
      #       elevator
      #   end

      # send new elevator to all slaves
      # {_m, _bs} = GenServer.multi_call(StateServer, {:set_elevator, node_name, elevator})

      # pull everyones elevator state
      {el_states_map, _bs} = GenServer.multi_call([NodeConnector.get_self() | Node.list()], StateDistribution, :get_state)

      # get my system state
      master_sys_state = SS.get_state()

      elevators_old = master_sys_state.elevators
      # update my state with everyone elses, need to do for each put map
      elevators_new =
        el_states_map
        |> Enum.reduce(
          elevators_old,
          # probably not needed but check counter before put? :)
          fn {node_name, el_state}, els -> Map.put(els, node_name, el_state) end
        )
        ## add new elevator
        #|> Map.put(node_name, elevator)

      # add to system state
      master_sys_state = %{master_sys_state | elevators: elevators_new}
      # push
      GenServer.multi_call(SS, {:set_state, master_sys_state})

      {:noreply, state}
    else
      # currently not in use
      IO.puts("something wrong with dist")
      {:noreply, state}
    end
  end

  # utils ----------------------------------------

  defp update_cab_requests(elevator, latest_elevator) do
    # Adds all cab requests from latest_elevator to elevators requests
    # Probably not needed...

    IO.puts("updating cab requests!!")

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

  # defp update_hall_requests(req, floor, btn_type, state) do
  #   # TODO make this a config maybe?
  #   # valid_buttons = [0, 1]
  #   # also check floor and btn_type beforehand!

  #   req_list = req.hall_orders

  #   if state in @valid_hall_request_states and btn_type in @hall_btn_types do
  #     {req_at_floor, _list} = List.pop_at(req_list, floor)
  #     updated_req_at_floor = List.replace_at(req_at_floor, @hall_btn_map[btn_type], state)
  #     new_req_list = List.replace_at(req_list, floor, updated_req_at_floor)
  #     %StateServer.HallRequests{req | hall_orders: new_req_list}
  #   else
  #     {:error, "not valid hall request state!"}
  #   end
  # end
end
