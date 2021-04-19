defmodule StateServer do
  use GenServer

  defmodule HallOrder do
    @moduledoc """
      Hall Requests struct.
    """

    @btn_map Application.fetch_env!(:elevator_project, :button_map)
    @hall_btn_map Map.drop(@btn_map, [:btn_cab])

    @btn_types Application.fetch_env!(:elevator_project, :button_types)

    @hall_btn_types List.delete(@btn_types, :btn_cab)
    @hall_btn_states [:new, :done, :assigned]

    @type hall_btn_state :: :new | :assigned | :done
    @type hall_req_list :: [[hall_btn_state(), ...], ...]

    defstruct floor: nil, btn_type: nil, state: :done

    @type t :: %__MODULE__{
            floor: boolean(),
            btn_type: Elevator.hall_btn_type(),
            state: hall_btn_state()
          }

    @spec update_hall_requests_logic(
            hall_req_list(),
            Elevator.floor(),
            Elevator.hall_btn_type(),
            hall_btn_state()
          ) ::
            {:error, String.t()} | hall_req_list()
    @doc """
    Returns an updated hall_requests list with `hall_state` set at `floor`, `btn_type`.
    """
    def update_hall_requests_logic(req_list, floor, btn_type, hall_state) do
      # TODO make this a config maybe?
      # valid_buttons = [0, 1]
      # also check floor and btn_type beforehand!

      if hall_state in @hall_btn_states and btn_type in @hall_btn_types do
        {req_at_floor, _list} = List.pop_at(req_list, floor)
        updated_req_at_floor = List.replace_at(req_at_floor, @hall_btn_map[btn_type], hall_state)
        new_req_list = List.replace_at(req_list, floor, updated_req_at_floor)
        new_req_list
      else
        {:error, "not valid hall request state!"}
      end
    end

    def update_hall_requests_logic(req_list, hall_order = %HallOrder{}) do
      if hall_order.state in @hall_btn_states and hall_order.btn_type in @hall_btn_types do
        {req_at_floor, _list} = List.pop_at(req_list, hall_order.floor)

        updated_req_at_floor =
          List.replace_at(req_at_floor, @hall_btn_map[hall_order.btn_type], hall_order.state)

        new_req_list = List.replace_at(req_list, hall_order.floor, updated_req_at_floor)
        new_req_list
      else
        {:error, "not valid hall request state!"}
      end
    end
  end

  defmodule SystemState do
    @moduledoc """
      System state struct.
    """

    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    @num_hall_req_types 2

    new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)
    defstruct hall_requests: new_hall_orders, elevators: %{}

    @type req_list :: [[StateServer.HallOrder.hall_btn_state(), ...], ...]

    @type t :: %__MODULE__{
            hall_requests: req_list(),
            elevators: %{node() => Elevator.t()}
          }
  end

  # Client ----------------------------------------

  @spec start_link([]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec get_state :: StateServer.SystemState.t()
  @doc """
  Returns the `SystemState`.
  """
  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  @spec get_elevator(node()) :: Elevator.t()
  @doc """
  Returns the `Elevator` struct at node `node_name`.
  If there is no elevator in `SystemState` corresponding to that node, it returns a new `Elevator` struct
  """
  def get_elevator(node_name) do
    GenServer.call(__MODULE__, {:get_elevator, node_name})
  end

  @spec get_hall_requests :: StateServer.SystemState.req_list()
  @doc """
  Returns the hall requests list containing all hall orders.
  """
  def get_hall_requests() do
    GenServer.call(__MODULE__, :get_hall_requests)
  end

  @spec node_active(node(), boolean()) :: :abcast
  @doc """
  Distribute if the node `node_name` is active or not
  """
  def node_active(node_name, active_state) do
    nodes = [node() | Node.list()]

    GenServer.abcast(
      nodes,
      __MODULE__,
      {:node_active, node_name, active_state}
    )
  end

  @spec set_elevator(node(), Elevator.t()) :: :ok | {:error, String.t()}
  @doc """
  Sets the `Elevator` state corresponding to node `node_name` in `SystemState`.
  Performs a check to see if the elevator state is valid before writing it to state.
  """
  def set_elevator(node_name, elevator) do
    case Elevator.check(elevator) do
      {:error, msg} ->
        {:error, msg}

      {:ok, ^elevator} ->
        elevator = %Elevator{elevator | counter: elevator.counter + 1}
        nodes = [node() | Node.list()]
        GenServer.abcast(nodes, __MODULE__, {:set_elevator, node_name, elevator})
        :ok
    end
  end

  @spec update_hall_requests(
          node() | :local,
          Elevator.floor(),
          Elevator.hall_btn_type(),
          HallOrder.hall_btn_state()
        ) :: :abcast
  @doc """
  Updates the hall request in `StateServer` for node `node_name`.
  If node_name = `:local` it distributes the hall request update
  """
  def update_hall_requests(node_name \\ :local, floor_ind, btn_type, hall_state) do
    nodes = [node() | Node.list()]

    GenServer.abcast(
      nodes,
      __MODULE__,
      {:update_hall_requests, node_name, floor_ind, btn_type, hall_state}
    )
  end

  # calls----------------------------------------

  @impl true
  @spec init(any) :: {:ok, StateServer.SystemState.t()}
  def init(_opts) do
    wait_for_master_startup()
    {:ok, %StateServer.SystemState{}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:get_elevator, node_name}, _from, state) do
    elevator_state = get_elevator_init(node_name, state.elevators)
    {:reply, elevator_state, state}
  end

  @impl true
  def handle_call(:get_hall_requests, _from, state) do
    {:reply, state.hall_requests, state}
  end

  # casts----------------------------------------

  @impl true
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

  @impl true
  def handle_cast({:set_state, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_hall_requests, node_name, floor_ind, btn_type, hall_state}, state) do
    hall_requests = state.hall_requests

    new_hall_requests =
      HallOrder.update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

    state = %SystemState{state | hall_requests: new_hall_requests}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:node_active, node_name, active_state}, state) do
    el_state = get_elevator_init(node_name, state.elevators)

    if (not el_state.obstructed and active_state) or not active_state do
      el_state = %Elevator{el_state | active: active_state}

      new_state = %SystemState{
        state
        | elevators: Map.put(state.elevators, node_name, el_state)
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  ## Utils ------------------------------

  defp get_elevator_init(node_name, elevators) do
    case Map.get(elevators, node_name) do
      nil ->
        %Elevator{}

      elevator_state ->
        elevator_state
    end
  end

  defp wait_for_master_startup() do
    # Ensures that we do not register :nonode@nohost in the elevator map
    if :global.whereis_name(StateUpdater) == :undefined do
      Process.sleep(10)
      wait_for_master_startup()
    end
  end
end
