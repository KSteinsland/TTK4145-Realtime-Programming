defmodule RequestHandler do
    use GenServer

    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
    @btn_types_map Application.fetch_env!(:elevator_project, :button_map)
    @num_hall_order_types 2

    def start_link([]) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init([]) do 
        #Assign all new incase there was a reboot.
        sys_state = StateDist.get_state
        new_reqs = find_new_hall_requests(sys_state.hall_requests)
        empty_wd_list = List.duplicate(nil, @num_hall_order_types) |> List.duplicate(@num_floors)
        wd_list = handle_new_hall_requests(new_reqs, wd_list) 
        {:ok, wd_list}
    end

    def new_state(sys_state) do
        Genserver.cast(__MODULE__, {:new_state, sys_state})
    end

    @doc """
    kill watchdog for done requests.
    Assign and start watchdog timer for new requests.
    """
    def handle_cast({:new_state, sys_state}, wd_list) do
        done_reqs = find_hall_requests(sys_state.hall_requests.hall_orders, :done)
        wd_list = handle_done_hall_requests(done_reqs, wd_list)
        
        new_reqs = find_hall_requests(sys_state.hall_requests.hall_orders, :new)
        wd_list = handle_new_hall_requests(new_reqs, wd_list)

        {:ok, wd_list}
    end

    @doc """
    For all new requests: assign and start watchdog. Returns a new watchdog list 
    """
    def handle_new_hall_requests(new_requests, wd_list) do
        
        Enum.reduce(new_requests, wd_list, fn {floor, btn_type}, wd_list -> 
            assignee = Assignment.get_assignee(sys_state)
            StateDist.update_hall_requests(assignee, floor, btn_type, :exec)

            pid = spawn(__MODULE__, :watchdog, assignee, floor, btn_type)
            wd_list = List.update_at(Enum.at(wd_list, floor),  @btn_types_map(btn_type), pid) 
        end)
    end


    @doc """
    For all done requests: kill watchdog timer. Returns a new watchdog list  
    """
    def handle_done_hall_requests(done_requests, wd_list) do
        Enum.reduce(new_requests, wd_list, fn {floor, btn_type}, wd_list -> 
            pid = Enum.at(Enum.at(wd_list, floor), @btn_types_map(btn_type), floor)
            send(pid, :done)
            wd_list = List.update_at(Enum.at(wd_list, floor), @btn_types_map(btn_type), nil)
        end)
    end

    @doc """
    Takes in hall_requests, returns a list of tuples of finds {floor, btn_type} that contain new/done orders
    [[:done, :done], [:done, :done], [:done, :done], [:done, :done]]
    """
    def find_hall_requests(hall_requests, type) do
        r = Enum.with_index(List.flatten(hall_requests))
        Enum.reduce(r, [], fn {t, i}, finds -> 
            if t == type do
                finds ++ [{div(i,@num_hall_order_types), rem(i, @num_hall_order_types)}]
            else
                finds
            end
        end)
    end

    def watchdog(assignee, floor, btn_type) do
        receive do
            {:done} ->
                Process.exit(self(), :normal)

        after 
            @timeout_ms -> 
                StateDist.update_hall_requests(assignee, floor, btn_type, :new)
                StateDist.node_active(assignee, :inactive)
        end
    end
end