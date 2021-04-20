defmodule StateSynchronizer do
  use GenServer

  @moduledoc """
    Handles synchronizing of state when a node joins.
    Gets called both when a node starts up, and when it regains network connection.
    Master only process
  """

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  # client ----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def init(_opts) do
    {:ok, %{}}
  end

  @spec update_node(node()) :: :ok
  @doc """
  Updates the node `node_name` on re-/connection.
  """
  def update_node(node_name) do
    GenServer.cast(
      {:global, StateSynchronizer},
      {:update_node, node_name}
    )
  end

  # casts ----------------------------------------

  def handle_cast({:update_node, node_name}, _state) do
    # Updates a node that has just connected

    # Fetch hall requests from node
    node_hall_requests = GenServer.call({StateServer, node_name}, :get_hall_requests)

    # Notify all other nodes about node's hall requests
    Enum.with_index(node_hall_requests)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {hall_state, hall_ind} ->
        btn_type = @hall_btn_types |> Enum.at(hall_ind)

        case hall_state do
          :done ->
            :ok

          # :new, :assigned
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

    # Fetch local elevator state from node
    node_elevator = GenServer.call({StateServer, node_name}, {:get_elevator, node_name})

    ## Update the system state on the connected node
    # This will overwrite the node's local elevator state if
    # the master's copy of the nodes elevator state is newer
    # thus ensuring that the node regains its cab orders
    master_sys_state = StateServer.get_state()
    GenServer.cast({StateServer, node_name}, {:set_state, master_sys_state})

    ## Notify all other nodes about the node's elevator state
    # This will only be accepted if the node's elevator state is
    # newer than the copy all other nodes have beforehand
    StateServer.set_elevator(node_name, node_elevator)

    # Set all lights
    spawn(fn -> LightHandler.light_check(master_sys_state.hall_requests, nil) end)

    {:noreply, %{}}
  end
end
