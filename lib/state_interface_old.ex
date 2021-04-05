defmodule StateInterfaceOld do
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
  # def get_state do
  #   wait_for_node_startup()

  #   if Map.has_key?(SS.get_state().elevators, NodeConnector.get_state().name()) do
  #     SS.get_state().elevators
  #     |> Map.get(NodeConnector.get_state().name())
  #   else
  #     set_state(%Elevator{})

  #     %Elevator{}
  #   end
  # end
  def get_state do
    NodeConnector.wait_for_node_startup()
    StateDistribution.get_state()
  end

  @doc """
  sets elevator state on this node in system state
  """
  def set_state(%Elevator{} = elevator) do
    NodeConnector.wait_for_node_startup()

    case Elevator.new(elevator) do
      {:error, msg} ->
        {:error, msg}

      ^elevator ->
        # remnants of kriss...
        # pull everyones state
        {m, _bs} = GenServer.multi_call(StateServer, :get_state)
        # extract my system state
        sys_state = Map.get(Map.new(m), NodeConnector.get_state().name())
        elevators_old = sys_state.elevators
        # update my state with everyone elses, need to do for each put map
        elevators_new =
          Enum.map(m, fn {k, v} -> {k, v.elevators[k]} end)
          |> Enum.reduce(elevators_old, fn {k, v}, els -> Map.put(els, k, v) end)
          # add new elevator
          |> Map.put(NodeConnector.get_state().name(), elevator)

        # add to system state
        sys_state = %{sys_state | elevators: elevators_new}
        # push
        GenServer.multi_call(SS, {:set_state, sys_state})

        :ok
    end
  end
end
