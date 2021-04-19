defmodule StateSynchronizer do
  use GenServer

  @moduledoc """
    Handles synchronizing of state when a node joins.
    Master only process
  """

  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)
  @hall_btn_types List.delete(@btn_types, :btn_cab)

  alias StateServer, as: SS

  # client ----------------------------------------
  def start_link([]) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def init(_opts) do
    {:ok, %{last_hall_requests: nil}}
  end

  @spec update_node(node()) :: :ok
  @doc """
  Update the node `node_name` on re-/connection.
  """
  def update_node(node_name) do
    GenServer.call(
      {:global, StateSynchronizer},
      {:update_node, node_name}
    )
  end

  # casts ----------------------------------------

  def handle_call({:update_node, node_name}, _from, state) do
    # update a node that has just connected

    # update hall requests from node
    node_hall_requests = GenServer.call({StateServer, node_name}, :get_hall_requests)

    Enum.with_index(node_hall_requests)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {hall_state, hall_ind} ->
        btn_type = @hall_btn_types |> Enum.at(hall_ind)

        case hall_state do
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
    IO.inspect(node_elevator)

    local_copy = StateServer.get_elevator(node_name)
    update_cab_requests(local_copy.requests, node_name)

    node_elevator = %Elevator{
      node_elevator
      | counter: Enum.max([node_elevator.counter, local_copy.counter]) + 1
    }

    IO.inspect(node_elevator)

    # update nodes system state
    master_sys_state = SS.get_state()

    master_sys_state = %StateServer.SystemState{
      master_sys_state
      | elevators: Map.put(master_sys_state.elevators, node_name, node_elevator)
    }

    GenServer.cast({StateServer, node_name}, {:set_state, master_sys_state})

    # put nodes elevator state back
    StateServer.set_elevator(node_name, node_elevator)

    # set all lights
    spawn(fn -> LightHandler.light_check(master_sys_state.hall_requests, nil) end)

    {:reply, :ok, state}
  end

  # utils ----------------------------------------

  defp old_update_cab_requests(elevator, latest_elevator) do
    # Adds all cab requests from latest_elevator to elevators requests

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

  defp update_cab_requests(requests, node_name) do
    # Adds all cab requests from latest_elevator to elevators requests

    IO.puts("updating cab requests!!")

    Enum.with_index(requests)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {btn, btn_ind} ->
        btn_type = @btn_types |> Enum.at(btn_ind)

        case btn do
          1 ->
            ElevatorController.send_request(
              node_name,
              floor_ind,
              btn_type
            )

          _ ->
            :ok
        end
      end)
    end)
  end
end
