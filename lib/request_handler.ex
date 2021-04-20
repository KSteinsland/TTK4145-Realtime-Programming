defmodule ReqState do
  @moduledoc """
    Hall req handler state struct.
  """

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_hall_req_types 2

  new_hall_orders = List.duplicate(:done, @num_hall_req_types) |> List.duplicate(@num_floors)
  defstruct hall_requests: new_hall_orders, wd_list: []
end

defmodule RequestHandler do
  use GenServer

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @button_types Application.fetch_env!(:elevator_project, :button_types)
  @timeout_ms Application.fetch_env!(:elevator_project, :watchdog_timeout_ms)
  @num_hall_order_types 2

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  # TODO use tasksupervisor!

  def init([]) do
    state = %ReqState{}
    # sys_state = get_sys_state()
    # IO.inspect(sys_state.hall_requests)
    # spawn(fn -> LightHandler.light_check(sys_state.hall_requests, nil) end)
    # new_reqs = find_hall_requests(sys_state.hall_requests, :assigned)
    # new_reqs = new_reqs ++ find_hall_requests(sys_state.hall_requests, :new)

    # # All assigned should be made new incase reboot
    # hall_reqs = hall_reqs_replace(sys_state.hall_requests, :assigned, :new)
    # sys_state = %{sys_state | hall_requests: hall_reqs}

    empty_wd_list = List.duplicate(nil, @num_hall_order_types) |> List.duplicate(@num_floors)
    # wd_list = handle_new_hall_requests(new_reqs, empty_wd_list, sys_state)

    state = %{state | wd_list: empty_wd_list}

    {:ok, state}
  end

  def new_state() do
    GenServer.cast({:global, __MODULE__}, :new_state)
  end

  def get_wd() do
    GenServer.call({:global, __MODULE__}, :get_wd)
  end

  def get_state() do
    GenServer.call({:global, __MODULE__}, :get_state)
  end

  def get_sys_state(hall_requests) do
    {replies, _failues} = GenServer.multi_call(ElServer, :get_elevator)

    elevators =
      Enum.reduce(replies, %{}, fn {node, state}, elevators ->
        Map.put(elevators, node, state)
      end)

    %{elevators: elevators, hall_requests: hall_requests}
  end

  def handle_call(:get_sys_state, _from, state) do
    {replies, _failues} = GenServer.multi_call(ElServer, :get_elevator)

    elevators =
      Enum.reduce(replies, %{}, fn {node, state}, elevators ->
        Map.put(elevators, node, state)
      end)

    sys_state = %{elevators: elevators, hall_requests: state.hall_requests}

    {:reply, sys_state, state}
  end

  def handle_call(:get_wd, _from, state) do
    {:reply, state.wd_list, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def update_hall_requests(floor_ind, btn_type, hall_state) do
    GenServer.cast(
      {:global, __MODULE__},
      {:update_hall_requests, floor_ind, btn_type, hall_state}
    )
  end

  def handle_cast({:update_hall_requests, floor, btn_type, hall_state}, state) do
    # IO.puts("here")
    # hall_requests = state.hall_requests

    # valid? = HallOrder.valid_hall_request_change?(hall_requests, floor_ind, btn_type, hall_state)
    # if valid? do

    #   new_hall_requests =
    #     HallOrder.update_hall_requests_logic(hall_requests, floor_ind, btn_type, hall_state)

    #   state = %{state | hall_requests: new_hall_requests}

    #   {:noreply, state}
    # else
    #   {:noreply, state}
    # end


    {wd_list, hall_reqs} =
      case state do
        :new ->
          spawn(fn -> LightHandler.light_check(state.hall_requests, nil) end)
          wd_list = handle_new_hall_req(state.wd_list, floor, btn_type)
          hall_reqs = HallOrder.update_hall_requests_logic(state.hall_requests, floor, btn_type, :assigned)
          {wd_list, hall_reqs}

        :done ->
          wd_list = handle_done_hall_req(state.wd_list, floor, btn_type)
          hall_reqs = HallOrder.update_hall_requests_logic(state.hall_requests, floor, btn_type, :new)
          {wd_list, hall_reqs}
      end
      {:noreply, %{hall_requests: hall_reqs, wd_list: wd_list}}
  end

  def handle_new_hall_req(wd_list, floor, btn_type) do

    sys_state = get_sys_state(hall_reqs)

    pid = Enum.at(wd_list, floor) |> Enum.at(btn_type)
    if is_pid(pid), do: send(pid, :die)

    assignee = Assignment.assign(sys_state)

    ElevatorController.send_request(
      assignee,
      floor,
      Enum.at(@button_types, btn_type)
    )

    pid = spawn(__MODULE__, :watchdog, [assignee, floor, btn_type, self()])
    wd_list_replace_at(wd_list, floor, btn_type, pid)
  end

  def handle_done_hall_req(wd_list, floor, btn_type) do
    wd_pid = Enum.at(Enum.at(wd_list, floor), btn_type)

    case wd_pid do
      nil ->
        :noop

      pid ->
        send(pid, :done)
        IO.puts("sent hall req confirmation")
    end

    wd_list_replace_at(wd_list, floor, btn_type, nil)
  end

  @doc """
  kill watchdog for done requests.
  Assign and start watchdog timer for new requests.
  """
  def handle_cast(:new_state, state) do
    sys_state = get_sys_state(state.hall_requests)

    wd_list = state.wd_list

    spawn(fn -> LightHandler.light_check(sys_state.hall_requests, nil) end)

    done_reqs = find_hall_requests(sys_state.hall_requests, :done)
    wd_list = handle_done_hall_requests(done_reqs, wd_list)

    new_reqs = find_hall_requests(sys_state.hall_requests, :new)
    wd_list = handle_new_hall_requests(new_reqs, wd_list, sys_state)

    state = %{state | wd_list: wd_list}

    {:noreply, state}
  end

  def handle_info({:try_active, node_name}, state) do
    StateServer.node_active(node_name, true)
    {:noreply, state}
  end

  @doc """
  For all new requests: assign and start watchdog. Returns a new watchdog list
  """
  def handle_new_hall_requests(new_requests, wd_list, sys_state, hall_reqs) do
    Enum.reduce(new_requests, wd_list, fn {floor, btn_type}, {wd_list, hall_reqs} ->
      pid = Enum.at(wd_list, floor) |> Enum.at(btn_type)
      if is_pid(pid), do: send(pid, :die)

      assignee = Assignment.assign(sys_state)

      # StateServer.update_hall_requests(
      #   assignee,
      #   floor,
      #   Enum.at(@button_types, btn_type),
      #   :assigned
      # )
      hall_reqs = HallOrder.update_hall_requests_logic(hall_reqs, floor, btn_type, :assigned)

      ElevatorController.send_request(
        assignee,
        floor,
        Enum.at(@button_types, btn_type)
      )

      pid = spawn(__MODULE__, :watchdog, [assignee, floor, btn_type, self()])
      {wd_list_replace_at(wd_list, floor, btn_type, pid), hall_reqs}
    end)
  end

  @doc """
  For all done requests: kill watchdog timer. Returns a new watchdog list
  """
  def handle_done_hall_requests(done_requests, wd_list) do
    Enum.reduce(done_requests, wd_list, fn {floor, btn_type}, wd_list ->
      wd_pid = Enum.at(Enum.at(wd_list, floor), btn_type)

      case wd_pid do
        nil ->
          :noop

        pid ->
          send(pid, :done)
          IO.puts("sent hall req confirmation")
      end

      wd_list_replace_at(wd_list, floor, btn_type, nil)
    end)
  end

  @doc """
  Takes in hall_requests, returns a list of tuples of finds {floor, btn_type} that contain new/done orders
  """
  def find_hall_requests(hall_requests, type) do
    r = Enum.with_index(List.flatten(hall_requests))

    Enum.reduce(r, [], fn {t, i}, finds ->
      if t == type do
        finds ++ [{div(i, @num_hall_order_types), rem(i, @num_hall_order_types)}]
      else
        finds
      end
    end)
  end

  def wd_list_replace_at(wd_list, floor, btn_type, value) do
    f = List.replace_at(Enum.at(wd_list, floor), btn_type, value)
    List.replace_at(wd_list, floor, f)
  end

  def watchdog(assignee, floor, btn_type, caller) do
    receive do
      :done ->
        IO.puts("confirmed done!")
        Process.exit(self(), :normal)

      :die ->
        IO.puts("killed prev wd!")
        Process.exit(self(), :normal)
    after
      @timeout_ms ->
        IO.puts("time out!!")

        StateServer.node_active(assignee, false)

        StateServer.update_hall_requests(
          assignee,
          floor,
          Enum.at(@button_types, btn_type),
          :new
        )

        RequestHandler.new_state()
        Process.send_after(caller, {:try_active, assignee}, 10_000)
        Process.exit(self(), :normal)
    end
  end

  def hall_reqs_replace(hall_reqs, from, to) do
    Enum.reduce(hall_reqs, [], fn [one, two], acc ->
      m1 = Map.new([{from, to}])
      m2 = Map.new([{nil, one}, {to, to}])
      m3 = Map.new([{nil, two}, {to, to}])

      acc ++ [[m2[m1[one]], m3[m1[two]]]]
    end)
  end
end

defmodule HallOrder do
  @moduledoc """
    Hall Requests struct.
  """

  @btn_map Application.fetch_env!(:elevator_project, :button_map)
  @hall_btn_map Map.drop(@btn_map, [:btn_cab])

  @btn_types Application.fetch_env!(:elevator_project, :button_types)

  @hall_btn_types List.delete(@btn_types, :btn_cab)
  @hall_btn_states [:new, :assigned, :done]

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

  def valid_hall_request_change?(req_list, floor, btn_type, hall_state) do
    current_hall_state = Enum.at(Enum.at(req_list, floor), Map.get(@hall_btn_map, btn_type))

    current_index =
      Enum.find_index(@hall_btn_states, fn hall_btn_state ->
        current_hall_state == hall_btn_state
      end)

    index =
      Enum.find_index(@hall_btn_states, fn hall_btn_state -> hall_state == hall_btn_state end)

    Integer.mod(current_index + 1, 3) == index
  end
end
