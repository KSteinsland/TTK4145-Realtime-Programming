defmodule StateUpdater do
  use GenServer

  @moduledoc """
    Handles distribution of state and calling on request assigning and execution.
    Master only process
  """

  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)
  @hall_btn_types_map Map.delete(@btn_types_map, :btn_cab)

  alias StateServer, as: SS

  # client ----------------------------------------
  def start_link([]) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def init(_opts) do
    {:ok, %{last_hall_requests: nil}}
  end

  @spec node_active(node(), boolean()) :: :ok
  @doc """
  Distribute if the node `node_name` is active or not
  """
  def node_active(node_name, active_state) do
    GenServer.cast(
      {:global, StateUpdater},
      {:node_active, node_name, active_state}
    )
  end

  @spec update_node(node()) :: :ok
  @doc """
  Update the node `node_name` on re-/connection.
  """
  def update_node(node_name) do
    GenServer.cast(
      {:global, StateUpdater},
      {:update_node, node_name}
    )
  end

  # casts ----------------------------------------

  def handle_cast({:update_node, node_name}, state) do
    # update a node that has just connected

    # update hall requests from node
    node_hall_requests = GenServer.call({StateServer, node_name}, :get_hall_requests)

    node_hall_requests
    |> Enum.with_index()
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.map(@hall_btn_types_map, fn {btn_type, btn_ind} ->
        case Enum.at(floor, btn_ind) do
          :done ->
            :ok

          # everything else
          hall_state ->
            StateServer.update_hall_requests(
              node_name,
              floor_ind,
              btn_type,
              hall_state
            )
        end
      end)
    end)

    node_elevator = GenServer.call({StateServer, node_name}, {:get_elevator, node_name})

    # update nodes system state
    master_sys_state = SS.get_state()
    GenServer.cast({StateServer, node_name}, {:set_state, master_sys_state})

    # put nodes elevator state back
    StateServer.set_elevator(node_name, node_elevator)

    # set all lights
    spawn(fn -> LightHandler.light_check(master_sys_state.hall_requests, nil) end)

    {:noreply, state}
  end

  def handle_cast({:node_active, node_name, active_state}, state) do
    el_state = SS.get_elevator(node_name)

    if (not el_state.obstructed and active_state) or not active_state do
      el_state = %Elevator{el_state | active: active_state}
      nodes = [Node.self() | Node.list()]
      GenServer.abcast(nodes, StateServer, {:set_elevator, node_name, el_state})
    end

    {:noreply, state}
  end
end
