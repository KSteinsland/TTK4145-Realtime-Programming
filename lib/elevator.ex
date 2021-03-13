defmodule Elevator do
  @moduledoc """
   Keeps Elevator state.
  """

  # defmodule ElevatorState
  # defmodule ElevatorState.Server

  use GenServer

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
  @directions Application.fetch_env!(:elevator_project, :directions)
  @behaviours Application.fetch_env!(:elevator_project, :behaviours)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)

  req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)

  defstruct floor: 0, direction: :dir_stop, requests: req_list, behaviour: :be_idle

  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  # API----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
    # , debug: [:trace])
  end

  def state() do
    GenServer.call(__MODULE__, :get_state)
  end

  # we need to separate the server keeping the state from the struct functions

  # no need to check if keys are valid, keyerror is thrown
  # but need to check values

  def new_state(%__MODULE__{} = elevator, key, val) do
    # check guards here
    Map.put(elevator, key, val)
  end

  def set_state(new_state) do
    # check guards here?
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  def get_floor() do
    GenServer.call(__MODULE__, :get_floor)
  end

  def get_direction() do
    GenServer.call(__MODULE__, :get_direction)
  end

  def get_requests() do
    GenServer.call(__MODULE__, :get_requests)
  end

  def get_behaviour() do
    GenServer.call(__MODULE__, :get_behaviour)
  end

  # when size is correct and data in requests is correct
  def set_requests(requests) do
    GenServer.cast(__MODULE__, {:set_requests, requests})
  end

  def set_floor(floor) when floor >= 0 and floor < @num_floors do
    GenServer.cast(__MODULE__, {:set_floor, floor})
  end

  def set_direction(direction) when direction in @directions do
    GenServer.cast(__MODULE__, {:set_direction, direction})
  end

  def set_behaviour(behaviour) when behaviour in @behaviours do
    GenServer.cast(__MODULE__, {:set_behaviour, behaviour})
  end

  def set_request(floor, btn_type)
      when btn_type in @btn_types and
             floor >= 0 and floor < @num_floors do
    GenServer.cast(__MODULE__, {:set_request, floor, btn_type})
  end

  def clear_request(floor, btn_type)
      when btn_type in @btn_types and
             floor >= 0 and floor < @num_floors do
    GenServer.cast(__MODULE__, {:clear_request, floor, btn_type})
  end

  # def clear_all_requests_at_floor(floor) when floor >= 0 and floor < @num_floors do
  #   GenServer.cast(__MODULE__, {:clear_all_requests_at_floor, floor})
  # end

  # Error matches--------------------------------
  # def set_floor(floor) do
  #   {:error, "Not a legal floor: #{floor}"}
  # end

  # def set_direction(direction) do
  #   {:error, "Not a legal direction: #{direction}"}
  # end

  # def set_behaviour(behaviour) do
  #   {:error, "Not a legal behaviour: #{behaviour}"}
  # end

  # def set_request(floor, btn_type) do
  #   {:error, "Bad request"}
  # end

  # def clear_request(floor, btn_type) do
  #   {:error, "Bad request"}
  # end

  # def clear_all_requests_at_floor(floor) do
  #   {:error, "Bad request"}
  # end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, _state) do
    # check guards!
    with {:ok, _floor} <- parse_floor(new_state.floor),
         {:ok, _direction} <- parse_direction(new_state.direction),
         {:ok, _requests} <- parse_requests(new_state.requests),
         {:ok, _behaviour} <- parse_behaviour(new_state.behaviour) do
      {:reply, :ok, new_state}
    else
      err -> err
    end
  end

  def handle_call(:get_floor, _from, state) do
    {:reply, state.floor, state}
  end

  def handle_call(:get_direction, _from, state) do
    {:reply, state.direction, state}
  end

  def handle_call(:get_requests, _from, state) do
    {:reply, state.requests, state}
  end

  def handle_call(:get_behaviour, _from, state) do
    {:reply, state.behaviour, state}
  end

  # casts----------------------------------------
  def handle_cast({:set_requests, requests}, state) do
    state = %{state | requests: requests}
    {:noreply, state}
  end

  def handle_cast({:set_floor, floor}, state) do
    state = %{state | floor: floor}
    {:noreply, state}
  end

  def handle_cast({:set_direction, direction}, state) do
    state = %{state | direction: direction}
    {:noreply, state}
  end

  def handle_cast({:set_request, floor, btn_type}, state) do
    req = update_requests(state.requests, floor, btn_type, 1)
    state = %{state | requests: req}
    {:noreply, state}
  end

  def handle_cast({:clear_request, floor, btn_type}, state) do
    req = update_requests(state.requests, floor, btn_type, 0)
    state = %{state | requests: req}
    {:noreply, state}
  end

  # def handle_cast({:clear_all_requests_at_floor, floor}, state) do
  #   b_req = List.duplicate(0, @num_buttons)
  #   req = List.replace_at(state.requests, floor, b_req)
  #   state = %{state | requests: req}
  #   {:noreply, state}
  # end

  def handle_cast({:set_behaviour, behaviour}, state) do
    state = %{state | behaviour: behaviour}
    {:noreply, state}
  end

  # guards-------------------------------------
  defp parse_floor(nil), do: {:error, "floor is required"}

  defp parse_floor(floor) when is_integer(floor) and floor < @num_floors and floor >= 0,
    do: {:ok, floor}

  defp parse_floor(_invalid), do: {:error, "floor must be a integer in range [0, #{@num_floors})"}

  defp parse_direction(nil), do: {:error, "direction is required"}

  defp parse_direction(direction) when is_atom(direction) and direction in @directions,
    do: {:ok, direction}

  defp parse_direction(_invalid), do: {:error, "direction must be a valid atom"}

  defp parse_requests(nil), do: {:error, "requests are required"}

  defp parse_requests(requests)
       when is_list(requests) and length(requests) == @num_floors and
              length(hd(requests)) == @num_buttons,
       do: {:ok, requests}

  defp parse_requests(_invalid),
    do: {:error, "requests must be a valid 2d list of size #{@num_floors}x#{@num_buttons}"}

  defp parse_behaviour(nil), do: {:error, "behaviour is required"}

  defp parse_behaviour(behaviour) when is_atom(behaviour) and behaviour in @behaviours,
    do: {:ok, behaviour}

  defp parse_behaviour(_invalid), do: {:error, "behaviour must be a valid atom"}

  # util----------------------------------------
  defp update_requests(req, floor, btn_type, value) do
    {req_at_floor, _list} = List.pop_at(req, floor)
    updated_req_at_floor = List.replace_at(req_at_floor, @btn_types_map[btn_type], value)
    List.replace_at(req, floor, updated_req_at_floor)
  end
end
