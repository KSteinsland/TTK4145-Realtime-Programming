defmodule StateDistribution do
  use GenServer

  @moduledoc """
    Handles distribution of state in the case of both master and slave status
  """

  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

  alias StateServer, as: SS

  # client----------------------------------------
  def start_link([]) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def update_hall_requests(master, floor_ind, btn_type, hall_state) do
    GenServer.cast(
      {StateDistribution, master},
      {:update_hall_requests, floor_ind, btn_type, hall_state}
    )
  end

  def node_active(master, node_name, active_state) do
    GenServer.cast(
      {StateDistribution, master},
      {:node_active, node_name, active_state}
    )
  end

  def update_node(master, node_name) do
    GenServer.cast(
      {StateDistribution, master},
      {:update_node, node_name}
    )
  end

  def update_requests(master, node_name) do
    GenServer.cast(
      {StateDistribution, master},
      {:update_requests, node_name}
    )
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
        SS.HallRequests.update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

      nodes = [NodeConnector.get_self() | Node.list()]

      GenServer.abcast(
        nodes,
        StateServer,
        {:set_hall_requests, new_hall_requests}
      )

      {:noreply, state}
    else
      # currently not in use
      {:noreply, state}
    end
  end

  def handle_cast({:new_state, node_name, elevator}, state) do
    if NodeConnector.get_role() == :master do
      # pull everyones elevator state
      nodes = List.delete([NodeConnector.get_self() | Node.list()], node_name)

      # {el_states_map, _bs} = GenServer.multi_call(nodes, StateDistribution, :get_state, 500)

      # get my system state
      master_sys_state = SS.get_state()
      elevators_old = master_sys_state.elevators

      # broadcast the new elevator change
      case Map.get(elevators_old, node_name) do
        nil ->
          GenServer.abcast(nodes, StateServer, {:set_elevator, node_name, elevator})

        el_old ->
          if elevator.counter >= el_old.counter do
            GenServer.abcast(nodes, StateServer, {:set_elevator, node_name, elevator})
          else
            # update cab requests?
            IO.puts("counter bad for #{node_name}!")
          end
      end

      # # broadcast all other elevator states
      # el_states_map
      # |> Enum.map(fn {node_name, el_state} ->
      #   case Map.get(elevators_old, node_name) do
      #     nil ->
      #       GenServer.abcast(StateServer, {:set_elevator, node_name, el_state})

      #     el_old ->
      #       if el_state.counter >= el_old.counter do
      #         GenServer.abcast(StateServer, {:set_elevator, node_name, el_state})
      #       else
      #         # update cab requests?
      #         IO.puts("counter bad!")
      #         GenServer.abcast(StateServer, {:set_elevator, node_name, el_old})
      #       end
      #   end
      # end)

      {:noreply, state}
    else
      # currently not in use
      IO.puts("something wrong with dist")
      {:noreply, state}
    end
  end

  def handle_cast({:update_node, node_name}, state) do
    # update a node that has just connected

    node_elevator = GenServer.call({StateServer, node_name}, {:get_elevator, node_name})

    master_sys_state = SS.get_state()
    local_copy = SS.get_elevator(node_name)

    # check if elevatorstate is outdated, probably not needed...
    node_elevator =
      cond do
        node_elevator.counter <= local_copy.counter and node_name != Node.self() ->
          IO.puts("Node outdated!")

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

    GenServer.cast({StateServer, node_name}, {:set_state, updated_sys_state})
    SS.set_state(updated_sys_state)

    {:noreply, state}
  end

  def handle_cast({:update_requests, node_name}, state) do
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
            {StateDistribution, Node.self()},
            {:update_hall_requests, floor_ind, :btn_hall_up, hall_state}
          )
      end

      case Enum.at(floor, 1) do
        :done ->
          :ok

        # everything else
        hall_state ->
          GenServer.cast(
            {StateDistribution, Node.self()},
            {:update_hall_requests, floor_ind, :btn_hall_down, hall_state}
          )
      end
    end)

    {:noreply, state}
  end

  def handle_cast({:node_active, node, active_state}, state) do
    if NodeConnector.get_role() == :master do
      GenServer.abcast(Node.list(), __MODULE__, {:node_active, node, active_state})
    end

    el_state = SS.get_elevator(node)
    el_state = %Elevator{el_state | active: active_state}
    SS.set_elevator(node, el_state)

    {:noreply, state}
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
end
