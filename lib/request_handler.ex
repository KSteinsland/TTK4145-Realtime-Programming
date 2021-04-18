defmodule RequestHandler do
  use GenServer

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @button_types Application.fetch_env!(:elevator_project, :button_types)
  @timeout_ms Application.fetch_env!(:elevator_project, :watchdog_timeout_ms)
  @num_hall_order_types 2


  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def init([]) do
    # All assigned should be made new incase reboot
    sys_state = StateServer.get_state()
    IO.inspect(sys_state.hall_requests.hall_orders)
    new_reqs = find_hall_requests(sys_state.hall_requests.hall_orders, :assigned)
    new_reqs = new_reqs ++ find_hall_requests(sys_state.hall_requests.hall_orders, :new)
    empty_wd_list = List.duplicate(nil, @num_hall_order_types) |> List.duplicate(@num_floors)
    wd_list = handle_new_hall_requests(new_reqs, empty_wd_list, sys_state)
    {:ok, wd_list}
  end

  def new_state(sys_state) do
    GenServer.cast({:global, __MODULE__}, {:new_state, sys_state})
  end

  def get_wd() do
    GenServer.call({:global, __MODULE__}, :get_wd)
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
    wd_list = handle_new_hall_requests(new_reqs, wd_list, sys_state)

    {:noreply, wd_list}
  end

  @doc """
  For all new requests: assign and start watchdog. Returns a new watchdog list
  """
  def handle_new_hall_requests(new_requests, wd_list, sys_state) do
    Enum.reduce(new_requests, wd_list, fn {floor, btn_type}, wd_list ->
      assignee = Assignment.assign(sys_state)

      StateDistribution.update_hall_requests(
        assignee,
        floor,
        Enum.at(@button_types, btn_type),
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
      # IO.inspect(wd_pid)

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

        StateDistribution.node_active(assignee, false)

        StateDistribution.update_hall_requests(
          assignee,
          floor,
          Enum.at(@button_types, btn_type),
          :new
        )

    end
  end
end
