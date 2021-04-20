defmodule HallRequestDelegator do
  use GenServer

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @button_types Application.fetch_env!(:elevator_project, :button_types)
  @timeout_ms Application.fetch_env!(:elevator_project, :watchdog_timeout_ms)
  @num_hall_order_types 2

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def init([]) do
    # Run the assignment procedure on all new and assigned hall reqs in case master restarted.
    sys_state = StateServer.get_state()
    spawn(fn -> LightHandler.light_check(sys_state.hall_requests, nil) end)

    new_reqs = find_hall_requests(sys_state.hall_requests, :assigned)
    new_reqs = new_reqs ++ find_hall_requests(sys_state.hall_requests, :new)

    hall_reqs = hall_reqs_replace(sys_state.hall_requests, :assigned, :new)
    sys_state = %{sys_state | hall_requests: hall_reqs}

    empty_wd_list = List.duplicate(nil, @num_hall_order_types) |> List.duplicate(@num_floors)
    wd_list = handle_new_hall_requests(new_reqs, empty_wd_list, sys_state)
    {:ok, wd_list}
  end

  @spec new_state :: :ok
  @doc """
  Kill watchdog for done requests.
  Assign and start watchdog timer for new requests.
  """
  def new_state() do
    GenServer.cast({:global, __MODULE__}, :new_state)
  end

  def handle_cast(:new_state, wd_list) do
    sys_state = StateServer.get_state()

    spawn(fn -> LightHandler.light_check(sys_state.hall_requests, nil) end)

    done_reqs = find_hall_requests(sys_state.hall_requests, :done)
    wd_list = handle_done_hall_requests(done_reqs, wd_list)

    new_reqs = find_hall_requests(sys_state.hall_requests, :new)
    wd_list = handle_new_hall_requests(new_reqs, wd_list, sys_state)

    {:noreply, wd_list}
  end

  def handle_info({:try_active, node_name}, state) do
    StateServer.node_active(node_name, true)
    {:noreply, state}
  end

  @spec handle_new_hall_requests(any, any, any) :: any
  @doc """
  For all new requests: assign and start watchdog. Returns a new watchdog list
  """
  def handle_new_hall_requests(new_requests, wd_list, sys_state) do
    Enum.reduce(new_requests, wd_list, fn {floor, btn_type}, wd_list ->
      pid = Enum.at(wd_list, floor) |> Enum.at(btn_type)
      if is_pid(pid), do: send(pid, :die)

      connected_elevators =
        Enum.reduce([node() | Node.list()], %{}, fn elevator, elevators ->
          Map.put(elevators, elevator, sys_state.elevators[elevator])
        end)

      assignee = Assignment.assign(%{sys_state | elevators: connected_elevators})

      StateServer.update_hall_requests(
        assignee,
        floor,
        Enum.at(@button_types, btn_type),
        :assigned
      )

      Elevator.Controller.send_request(
        assignee,
        floor,
        Enum.at(@button_types, btn_type)
      )

      pid = spawn(__MODULE__, :watchdog, [assignee, floor, btn_type, self()])
      wd_list_replace_at(wd_list, floor, btn_type, pid)
    end)
  end

  @spec handle_done_hall_requests(any, any) :: any
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

  @spec watchdog(node(), Elevator.floor(), Elevator.hall_btn_type(), pid()) :: true
  @doc """
  On a new hall order this watchdog should be spawned.
  If its not completed before timeout the hall order is resent,
  and the failed elevator is set to be non-active for 30sec.
  """
  def watchdog(assignee, floor, btn_type, caller) do
    receive do
      :done ->
        Process.exit(self(), :normal)

      :die ->
        Process.exit(self(), :normal)
    after
      @timeout_ms ->
        StateServer.node_active(assignee, false)

        StateServer.update_hall_requests(
          assignee,
          floor,
          Enum.at(@button_types, btn_type),
          :new
        )

        HallRequestDelegator.new_state()
        Process.send_after(caller, {:try_active, assignee}, 30_000)
        Process.exit(self(), :normal)
    end
  end

  defp hall_reqs_replace(hall_reqs, from, to) do
    Enum.reduce(hall_reqs, [], fn [one, two], acc ->
      m1 = Map.new([{from, to}])
      m2 = Map.new([{nil, one}, {to, to}])
      m3 = Map.new([{nil, two}, {to, to}])

      acc ++ [[m2[m1[one]], m3[m1[two]]]]
    end)
  end

  defp find_hall_requests(hall_requests, type) do
    r = Enum.with_index(List.flatten(hall_requests))

    Enum.reduce(r, [], fn {t, i}, finds ->
      if t == type do
        finds ++ [{div(i, @num_hall_order_types), rem(i, @num_hall_order_types)}]
      else
        finds
      end
    end)
  end

  defp wd_list_replace_at(wd_list, floor, btn_type, value) do
    f = List.replace_at(Enum.at(wd_list, floor), btn_type, value)
    List.replace_at(wd_list, floor, f)
  end
end
