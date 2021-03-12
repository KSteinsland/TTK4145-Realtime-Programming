defmodule Distributor do
    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
    @num_hall_order_types 2

    @timeout 1000*20 #20 sec 

    use GenServer

    def start_link([]) do 
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_opts) do
        active_orders = List.duplicate(0, @num_hall_order_types) |> List.duplicate(@num_floors)
        {:ok, active_orders}
    end

    def handle_info({:new_hall_order, floor, up?}, active_orders) do
        if not order_is_already_active?(active_orders, floor, up?) do
            Enum.each Node.list, fn node ->
                send({Distributor, node}, {:new_hall_order, floor, up?})
            end 
        
            if order_belongs_to_me(floor, up?) do
                Elevator.set_request(floor, %{true: 0, false: 1}[up?]) #this should be message, not call 
            end
            
            pid = spawn(__MODULE__, :watchdog, [floor, up?])
            active_orders = order_replace_at(active_orders, floor, up?, pid)
        end
        {:noreply, active_orders}
    end 


    def handle_info({:hall_order_finished, floor, up?}, active_orders) do
        Enum.each Node.list, fn node ->
            send({Distributor, node}, {:hall_order_finished, floor, up?})
        end 

        {active_orders, watchdog_pid} = order_finished(active_orders, floor, up?)
        send(watchdog_pid, {:hall_order_done, floor, up?})

        {:noreply, active_orders}
    end

    def watchdog(floor, up?) do
        receive do
            {:hall_order_done, floor, up?} -> 
                Process.exit(self, :normal)
        after 
            @timeout -> send(Distributor, {:new_hall_order, floor, up?})
        end
    end


    #Active hall order datatype, should be seperate module propably 
    #2D array (floor x button_type) of pids corresponding to watchdog processes

    def order_is_already_active?(active_orders, floor, up?) do
        {orders_at_floor, _rest} = List.pop_at(active_orders, floor)
        {order, _rest } = List.pop_at(orders_at_floor, %{true: 0, false: 1}[up?]) 
        order != 0
    end

    def order_replace_at(active_orders, floor, up?, value) do
        {orders_at_floor, _rest} = List.pop_at(active_orders, floor)
        orders_at_floor = List.replace_at(orders_at_floor, %{true: 0, false: 1}[up?], value)
        List.replace_at(active_orders, floor, orders_at_floor)
    end

    def order_belongs_to_me(floor, up?) do
        #TODO: assignment part here
        true
    end

    def order_finished(active_orders, floor, up?) do
        #TODO: if its not zero set to zero and return pid
    end
end
