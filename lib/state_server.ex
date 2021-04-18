defmodule StateServer do
  use GenServer

  defmodule HallRequests do
    @moduledoc """
      Hall Requests struct.
    """

    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    @num_hall_req_types 2

    @btn_map Application.fetch_env!(:elevator_project, :button_map)
    @hall_btn_map Map.drop(@btn_map, [:btn_cab])

    @btn_types Application.fetch_env!(:elevator_project, :button_types)

    @hall_btn_types List.delete(@btn_types, :btn_cab)
    @hall_btn_states [:new, :done, :assigned]

    @type hall_btn_state :: :new | :assigned | :done
    @type hall_req_list :: [[hall_btn_state(), ...], ...]

    new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)

    defstruct hall_orders: new_hall_orders

    @type t :: %__MODULE__{
            hall_orders: hall_req_list()
          }

    @spec update_hall_requests_logic(
            StateServer.HallRequests.t(),
            Elevator.floor(),
            Elevator.hall_btn_type(),
            hall_btn_state()
          ) ::
            {:error, String.t()} | StateServer.HallRequests.t()
    @doc """
    Returns an updated `HallRequests` struct with `hall_state` set at `floor`, `btn_type`.
    """
    def update_hall_requests_logic(req = %HallRequests{}, floor, btn_type, hall_state) do
      # TODO make this a config maybe?
      # valid_buttons = [0, 1]
      # also check floor and btn_type beforehand!

      req_list = req.hall_orders

      if hall_state in @hall_btn_states and btn_type in @hall_btn_types do
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
      System state struct.
    """

    defstruct hall_requests: %HallRequests{}, elevators: %{}

    @type t :: %__MODULE__{
            hall_requests: HallRequests.t(),
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

  @spec get_hall_requests :: StateServer.HallRequests.t()
  @doc """
  Returns the `HallRequests` struct containing all hall orders.
  """
  def get_hall_requests() do
    GenServer.call(__MODULE__, :get_hall_requests)
  end

  @spec set_elevator(node(), Elevator.t()) :: :ok | {:error, String.t()}
  @doc """
  Sets the `Elevator` state corresponding to node `node_name` in `SystemState`.
  Performs a check to see if the elevator state is valid before writing it to state.
  """
  def set_elevator(node_name, elevator) do
    # TODO move, Elevator check out of server?
    # and just use a cast?
    elevator = %Elevator{elevator | counter: elevator.counter + 1}
    GenServer.call(__MODULE__, {:set_elevator, node_name, elevator})
  end

  @spec update_hall_requests(
          node() | :local,
          Elevator.floor(),
          Elevator.hall_btn_type(),
          HallRequests.hall_btn_state()
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

  @impl true
  @spec init(any) :: {:ok, StateServer.SystemState.t()}
  def init(_opts) do
    NodeConnector.wait_for_node_startup()
    {:ok, %SystemState{}}
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

  @impl true
  def handle_call({:set_elevator, node_name, elevator}, _from, state) do
    case Elevator.check(elevator) do
      {:error, msg} ->
        {:reply, {:error, msg}, state}

      ^elevator ->
        old_elevator = get_elevator_init(node_name, state.elevators)

        if elevator.counter > old_elevator.counter do
          # sends new elevator state to master
          # master distributes it

          if old_elevator.obstructed != elevator.obstructed do
            StateDistribution.node_active(node_name, not elevator.obstructed)
          end

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
      HallRequests.update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

    if node_name == :local do
      StateDistribution.update_hall_requests(
        Node.self(),
        floor_ind,
        btn_type,
        hall_state
      )
    end

    state = %SystemState{state | hall_requests: new_hall_requests}
    {:noreply, state}
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
end
