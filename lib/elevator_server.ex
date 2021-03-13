defmodule Elevator.Server do
  use GenServer

  def init(_opts) do
    {:ok, %Elevator{}}
  end

  # client----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
    # , debug: [:trace])
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  # def get_floor() do
  #   GenServer.call(__MODULE__, :get_floor)
  # end

  # def get_direction() do
  #   GenServer.call(__MODULE__, :get_direction)
  # end

  # def get_requests() do
  #   GenServer.call(__MODULE__, :get_requests)
  # end

  # def get_behaviour() do
  #   GenServer.call(__MODULE__, :get_behaviour)
  # end

  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  # def set_requests(requests) do
  #   GenServer.cast(__MODULE__, {:set_requests, requests})
  # end

  # def set_floor(floor) when floor >= 0 and floor < @num_floors do
  #   GenServer.cast(__MODULE__, {:set_floor, floor})
  # end

  # def set_floor(floor) do
  #   {:error, "Not a legal floor: #{floor}"}
  # end

  # def set_direction(direction) when direction in @directions do
  #   GenServer.cast(__MODULE__, {:set_direction, direction})
  # end

  # def set_direction(direction) do
  #   {:error, "Not a legal direction: #{direction}"}
  # end

  # def set_behaviour(behaviour) when behaviour in @behaviours do
  #   GenServer.cast(__MODULE__, {:set_behaviour, behaviour})
  # end

  # def set_behaviour(behaviour) do
  #   {:error, "Not a legal behaviour: #{behaviour}"}
  # end

  # def set_request(floor, btn_type)
  #     when btn_type in @btn_types and
  #            floor >= 0 and floor < @num_floors do
  #   GenServer.cast(__MODULE__, {:set_request, floor, btn_type})
  # end

  # def set_request(floor, btn_type) do
  #   {:error, "Bad request"}
  # end

  # def clear_request(floor, btn_type)
  #     when btn_type in @btn_types and
  #            floor >= 0 and floor < @num_floors do
  #   GenServer.cast(__MODULE__, {:clear_request, floor, btn_type})
  # end

  # def clear_request(floor, btn_type) do
  #   {:error, "Bad request"}
  # end

  # def clear_all_requests_at_floor(floor) when floor >= 0 and floor < @num_floors do
  #   GenServer.cast(__MODULE__, {:clear_all_requests_at_floor, floor})
  # end

  # def clear_all_requests_at_floor(floor) do
  #   {:error, "Bad request"}
  # end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # def handle_call(:get_floor, _from, state) do
  #   {:reply, state.floor, state}
  # end

  # def handle_call(:get_direction, _from, state) do
  #   {:reply, state.direction, state}
  # end

  # def handle_call(:get_requests, _from, state) do
  #   {:reply, state.requests, state}
  # end

  # def handle_call(:get_behaviour, _from, state) do
  #   {:reply, state.behaviour, state}
  # end

  def handle_call({:set_state, new_state}, _from, state) do
    case Elevator.new(new_state) do
      {:error, msg} ->
        {:reply, {:error, msg}, state}
      _ ->
        {:reply, :ok, new_state}
    end
  end

# casts----------------------------------------
# def handle_cast({:set_requests, requests}, state) do
#   state = %{state | requests: requests}
#   {:noreply, state}
# end

# def handle_cast({:set_floor, floor}, state) do
#   state = %{state | floor: floor}
#   {:noreply, state}
# end

# def handle_cast({:set_direction, direction}, state) do
#   state = %{state | direction: direction}
#   {:noreply, state}
# end

# def handle_cast({:set_request, floor, btn_type}, state) do
#   req = update_requests(state.requests, floor, btn_type, 1)
#   state = %{state | requests: req}
#   {:noreply, state}
# end

# def handle_cast({:clear_request, floor, btn_type}, state) do
#   req = update_requests(state.requests, floor, btn_type, 0)
#   state = %{state | requests: req}
#   {:noreply, state}
# end

# def handle_cast({:clear_all_requests_at_floor, floor}, state) do
#   b_req = List.duplicate(0, @num_buttons)
#   req = List.replace_at(state.requests, floor, b_req)
#   state = %{state | requests: req}
#   {:noreply, state}
# end

# def handle_cast({:set_behaviour, behaviour}, state) do
#   state = %{state | behaviour: behaviour}
#   {:noreply, state}
# end

end
