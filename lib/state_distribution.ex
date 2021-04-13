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
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def update_hall_requests(floor_ind, btn_type, hall_state) do
    GenServer.cast(
      {StateDistribution, NodeConnector.get_master()},
      {:update_hall_requests, floor_ind, btn_type, hall_state}
    )
  end

  def node_active(node_name, active_state) do
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def get_state() do
    NodeConnector.wait_for_node_startup()
    GenServer.call(__MODULE__, :get_state)
  end

  # calls ----------------------------------------

  def handle_call(:get_state, _from, state) do
    elevator_state = SS.get_elevator(NodeConnector.get_self())
    {:reply, elevator_state, state}
  end

  # casts ----------------------------------------

  def handle_cast({:update_hall_requests, floor_ind, btn_type, hall_state}, state) do
    if NodeConnector.get_role() == :master do
      # TODO check state!
      # if state == :new do something
      # else if state == :done do something else

      hall_requests = SS.get_hall_requests()

      new_hall_requests =
        update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

      {_m, _bs} =
        GenServer.multi_call(
          [Node.self() | Node.list()],
          StateServer,
          {:set_hall_requests, new_hall_requests},
          400
        )

      {:noreply, state}
    else
      # currently not in use
      {:noreply, state}
    end
  end

  def handle_cast({:new_state, node_name, elevator}, state) do
    if NodeConnector.get_role() == :master do
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

      # pull everyones elevator state
      nodes = List.delete([NodeConnector.get_self() | Node.list()], node_name)
      {el_states_map, _bs} = GenServer.multi_call(nodes, StateDistribution, :get_state, 500)

      # get my system state
      master_sys_state = SS.get_state()
      elevators_old = master_sys_state.elevators

      # broadcast the new elevator change
      case Map.get(elevators_old, node_name) do
        nil ->
          GenServer.multi_call(nodes, SS, {:set_elevator, node_name, elevator})

        el_old ->
          if elevator.counter >= el_old.counter do
            GenServer.multi_call(nodes, SS, {:set_elevator, node_name, elevator})
          else
            # update cab requests?
            IO.puts("counter bad for new !")
          end
      end

      # broadcast all other elevator states
      el_states_map
      |> Enum.map(fn {node_name, el_state} ->
        case Map.get(elevators_old, node_name) do
          nil ->
            GenServer.multi_call(SS, {:set_elevator, node_name, el_state})

          el_old ->
            if el_state.counter >= el_old.counter do
              GenServer.multi_call(SS, {:set_elevator, node_name, el_state})
            else
              # update cab requests?
              IO.puts("counter bad!")
              GenServer.multi_call(SS, {:set_elevator, node_name, el_old})
            end
        end
      end)

      {:noreply, state}
    else
      # currently not in use
      IO.puts("something wrong with dist")
      {:noreply, state}
    end
  end

  def update_node(node_name) do
    # update a node that has just connected
    if NodeConnector.get_role() == :master do
      node_elevator = GenServer.call({StateServer, node_name}, :get_elevator)

      master_sys_state = SS.get_state()
      local_copy = SS.get_elevator(node_name)

      # check if elevatorstate is outdated, probably not needed...
      node_elevator =
        cond do
          node_elevator.counter <= local_copy.counter and node_name != NodeConnector.get_self() ->
            IO.puts("Old counter!")

            %Elevator{
              node_elevator
              | requests: update_cab_requests(node_elevator, local_copy),
                counter: local_copy.counter + 1
            }

          true ->
            node_elevator
        end

      updated_sys_state = %StateServer.SystemState{
        master_sys_state
        | elevators: Map.put(master_sys_state.elevators, node_name, node_elevator)
      }

      GenServer.call({StateServer, node_name}, {:set_state, updated_sys_state})
      SS.set_state(updated_sys_state)
    end
  end

  def update_requests(node_name) do
    node_state = GenServer.call({StateServer, node_name}, :get_state)

    node_hall_orders = node_state.hall_requests.hall_orders

    node_hall_orders
    |> Enum.with_index()
    |> Enum.map(fn {floor, floor_ind} ->
      case Enum.at(floor, 0) do
        :done ->
          :ok

        # everything else
        hall_state ->
          GenServer.cast(
            {StateDistribution, NodeConnector.get_master()},
            {:update_hall_requests, floor_ind, :btn_hall_up, hall_state}
          )
      end

      case Enum.at(floor, 1) do
        :done ->
          :ok

        # everything else
        hall_state ->
          GenServer.cast(
            {StateDistribution, NodeConnector.get_master()},
            {:update_hall_requests, floor_ind, :btn_hall_down, hall_state}
          )
      end
    end)
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
