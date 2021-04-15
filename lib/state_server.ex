defmodule StateServer do
  use GenServer

  defmodule HallRequests do
    @moduledoc """
      Hall Requests
    """

    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    # up down
    @num_hall_req_types 2

    @btn_map Application.fetch_env!(:elevator_project, :button_map)
    @hall_btn_map Map.drop(@btn_map, [:btn_cab])

    @btn_types Application.fetch_env!(:elevator_project, :button_types)
    @hall_btn_types List.delete(@btn_types, :btn_cab)

    @valid_hall_request_states [:new, :done, :assigned]

    @type hall_btn_states :: :new | :assigned | :done
    @type hall_btn_types :: :btn_hall_down | :btn_hall_up
    @type hall_req_list :: [[hall_btn_states(), ...], ...]

    new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)

    defstruct hall_orders: new_hall_orders

    @type t :: %__MODULE__{
            hall_orders: hall_req_list()
          }

    def update_hall_requests_logic(req, floor, btn_type, hall_state) do
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

  defmodule SystemState do
    @moduledoc """
      system state.
    """

    defstruct hall_requests: %HallRequests{}, elevators: %{}

    @type t :: %__MODULE__{
            hall_requests: HallRequests.t(),
            elevators: %{node() => Elevator.t()}
          }
  end

  def init(_opts) do
    wait_for_node_startup()
    {:ok, %SystemState{}}
  end

  # client----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_elevator(node_name) do
    GenServer.call(__MODULE__, {:get_elevator, node_name})
  end

  def get_hall_requests() do
    GenServer.call(__MODULE__, :get_hall_requests)
  end

  def set_elevator(node_name, elevator) do
    elevator = %Elevator{elevator | counter: elevator.counter + 1}
    GenServer.call(__MODULE__, {:set_elevator, node_name, elevator})
  end

  @spec update_hall_requests(
          node() | :local,
          Elevator.floors(),
          HallRequests.hall_btn_types(),
          HallRequests.hall_btn_states()
        ) :: :ok
  @doc """
  Updates the hall request in `StateServer` for node `node_name`.
  If node_name = `:local` it distributes the hall request update
  """
  def update_hall_requests(node_name \\ :local, floor_ind, btn_type, hall_state) do
    GenServer.cast(
      __MODULE__,
      {:update_hall_requests, node_name, floor_ind, btn_type, hall_state}
    )
  end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get_elevator, node_name}, _from, state) do
    elevator_state = get_elevator_init(node_name, state.elevators)
    {:reply, elevator_state, state}
  end

  def handle_call(:get_hall_requests, _from, state) do
    {:reply, state.hall_requests, state}
  end

  def handle_call({:set_elevator, node_name, elevator}, _from, state) do
    case Elevator.check(elevator) do
      {:error, msg} ->
        {:reply, {:error, msg}, state}

      ^elevator ->
        if elevator.counter > get_elevator_init(node_name, state.elevators).counter do
          # sends new elevator state to master
          # master distributes it

          # async call to master to update everybody
          StateDistribution.new_elevator_state(node_name, elevator)

          new_state = %SystemState{
            state
            | elevators: Map.put(state.elevators, node_name, elevator)
          }

          {:reply, :ok, new_state}
        else
          # IO.puts("bad counter on set el!")
          {:reply, :ok, state}
        end
    end
  end

  # casts----------------------------------------

  def handle_cast({:set_elevator, node_name, elevator}, state) do
    if elevator.counter > get_elevator_init(node_name, state.elevators).counter do
      new_state = %SystemState{
        state
        | elevators: Map.put(state.elevators, node_name, elevator)
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:set_state, new_state}, _state) do
    {:noreply, new_state}
  end

  def handle_cast({:update_hall_requests, node_name, floor_ind, btn_type, hall_state}, state) do
    hall_requests = state.hall_requests

    new_hall_requests =
      HallRequests.update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

    spawn(fn -> LightHandler.light_check(new_hall_requests, hall_requests) end)

    if node_name == :local do
      StateDistribution.update_hall_requests(
        NodeConnector.get_self(),
        floor_ind,
        btn_type,
        hall_state
      )
    end

    state = %SystemState{state | hall_requests: new_hall_requests}
    {:noreply, state}
  end

  ## Utils ------------------------------

  defp wait_for_node_startup() do
    if Node.self() == :nonode@nohost do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end

  defp get_elevator_init(node_name, elevators) do
    case Map.get(elevators, node_name) do
      nil ->
        %Elevator{}

      elevator_state ->
        elevator_state
    end
  end
end
