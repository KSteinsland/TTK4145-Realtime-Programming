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

  def set_state(%Elevator{} = elevator) do
    # do Elevator.new check first

    case NodeConnector.get_role() do
      :slave ->
        # send({__MODULE__, NodeConnector.get_master()}, {:new_state, NodeConnector.get_self(), elevator})
        status =
          GenServer.call(
            {__MODULE__, NodeConnector.get_master()},
            {:new_state, NodeConnector.get_self(), elevator}
          )

        case status do
          :ok ->
            SS.set_elevator(NodeConnector.get_self(), elevator)

          {:old_counter, latest_elevator} ->
            # todo merge latest elevator with new elevator in function call!
            new_elevator = %Elevator{elevator | requests: update_cab_requests(elevator, latest_elevator)}
            set_state(new_elevator)

        end

      :master ->
        nil
        # is no master part
    end
  end

  def update_cab_requests(elevator, latest_elevator) do
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

  def set_hall_request(state, floor_ind, btn_type) do
    sys_state = SS.get_state()

    # :done, :new
    new_hall_requests = update_hall_requests(sys_state.hall_requests, floor_ind, btn_type, state)

    SS.set_state(%{sys_state | hall_requests: new_hall_requests})
  end

  def handle_call({:new_state, node, elevator}, _from, state) do
    # just to be sure
    if NodeConnector.get_role() == :master do
      state = SS.get_state()
      # put elevator in state if counter is good
      # reply :ok

      # if counter not good,
      # reply {:old_counter, new_elevator}
    else
      {:reply, :error, state}
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
