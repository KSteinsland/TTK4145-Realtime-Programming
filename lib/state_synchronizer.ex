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

  def get_master_state() do
    GenServer.call(
      {:global, StateSynchronizer},
      :get_master_state
    )
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

  def handle_call(:get_master_state, from, state) do
    IO.inspect(from)
    {from_pid, _} = from

    if from_pid == Process.whereis(StateServer) do
      {:reply, %StateServer.SystemState{}, state}
    else
      {:reply, StateServer.get_state(), state}
    end
  end

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

    # local_copy = StateServer.get_elevator(node_name)
    # update_cab_requests(local_copy.requests, node_name)

    # update hall requests to node
    master_hall_requests = StateServer.get_hall_requests()

    # set all lights
    spawn(fn -> LightHandler.light_check(master_hall_requests, nil) end)

    Enum.with_index(master_hall_requests)
    |> Enum.map(fn {floor, floor_ind} ->
      Enum.with_index(floor)
      |> Enum.map(fn {hall_state, hall_ind} ->
        btn_type = @hall_btn_types |> Enum.at(hall_ind)

        case hall_state do
          :done ->
            :ok

          # everything else
          hall_state ->
            GenServer.cast(
              {StateServer, node_name},
              {:update_hall_requests, node_name, floor_ind, btn_type, hall_state}
            )
        end
      end)
    end)

    master_state = StateServer.get_state()

    Enum.map(master_state.elevators, fn {node_el, elevator} ->
      GenServer.cast({StateServer, node_name}, {:set_elevator, node_el, elevator})
    end)

    # put nodes elevator state back
    node_elevator = GenServer.call({StateServer, node_name}, {:get_elevator, node_name})
    IO.inspect(node_elevator)
    :ok = StateServer.set_elevator(node_name, node_elevator)

    {:reply, :ok, state}
  end

  # utils ----------------------------------------

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
