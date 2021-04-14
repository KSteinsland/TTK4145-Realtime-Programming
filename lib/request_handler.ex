defmodule RequestHandler do
  use GenServer

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)
  @btn_types_map_rev %{0 => :btn_hall_up, 1 => :btn_hall_down, 2 => :btn_cab}
  @num_hall_order_types 2
  @timeout_ms 20 * 1000

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  # defp wait_for_node_startup() do
  #   if NodeConnector.get_master() == nil do
  #     Process.sleep(10)
  #     wait_for_node_startup()
  #   end
  # end

  def init([]) do
    # wait_for_node_startup()
    # Assign all new incase there was a reboot.
    sys_state = StateDistribution.get_state()
    IO.inspect(sys_state.hall_requests.hall_orders)
    new_reqs = find_hall_requests(sys_state.hall_requests.hall_orders, :new)
    empty_wd_list = List.duplicate(nil, @num_hall_order_types) |> List.duplicate(@num_floors)
    wd_list = handle_new_hall_requests(new_reqs, empty_wd_list, sys_state)
    {:ok, wd_list}
  end

  def new_state(sys_state) do
    GenServer.cast({:global, __MODULE__}, {:new_state, sys_state})
  end

  def get_wd() do
    GenServer.call(__MODULE__, :get_wd)
  end

  def handle_call(:get_wd, _from, wd_list) do
    {:reply, wd_list, wd_list}
  end

  @doc """
  kill watchdog for done requests.
  Assign and start watchdog timer for new requests.
  """
  def handle_cast({:new_state, sys_state}, wd_list) do
    done_reqs = find_hall_requests(sys_state.hall_requests.hall_orders, :done)
    wd_list = handle_done_hall_requests(done_reqs, wd_list)

    new_reqs = find_hall_requests(sys_state.hall_requests.hall_orders, :new)
    # todo filter out inactive
    wd_list = handle_new_hall_requests(new_reqs, wd_list, sys_state)

    {:noreply, wd_list}
  end

  @doc """
  For all new requests: assign and start watchdog. Returns a new watchdog list
  """
  def handle_new_hall_requests(new_requests, wd_list, sys_state) do
    Enum.reduce(new_requests, wd_list, fn {floor, btn_type}, wd_list ->
      # assignee = Assignment.get_assignee(sys_state)
      # for now
      assignee = Node.self()

      StateDistribution.update_hall_requests(
        NodeConnector.get_master(),
        assignee,
        floor,
        @btn_types_map_rev[btn_type],
        :assigned
      )

      pid = spawn(__MODULE__, :watchdog, [assignee, floor, btn_type])
      wd_list_replace_at(wd_list, floor, btn_type, pid)
    end)
  end

  @doc """
  For all done requests: kill watchdog timer. Returns a new watchdog list
  """
  def handle_done_hall_requests(done_requests, wd_list) do
    Enum.reduce(done_requests, wd_list, fn {floor, btn_type}, wd_list ->
      wd_pid = Enum.at(Enum.at(wd_list, floor), btn_type)
      IO.inspect(wd_pid)

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

  def watchdog(assignee, floor, btn_type) do
    receive do
      :done ->
        IO.puts("confirmed done!")
        Process.exit(self(), :normal)
    after
      @timeout_ms ->
        IO.puts("time out!!")

        StateDistribution.update_hall_requests(
          NodeConnector.get_master(),
          assignee,
          floor,
          @btn_types_map_rev[btn_type],
          :new
        )

        StateDistribution.node_active(NodeConnector.get_master(), assignee, false)
    end
  end
end
