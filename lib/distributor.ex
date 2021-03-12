defmodule Distributor do
    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
    @num_hall_order_types 2

    @timeout 1000*20 #20 sec 

    def dist() do 
        active_orders = List.duplicate(0, @num_hall_order_types) |> List.duplicate(@num_floors)
        dist(active_orders)
    end

    def dist(active_orders) do
        receive do
            {:new_hall_order, floor, up?} ->

                if not order_is_already_active?(active_orders, floor, up?) do
                    Enum.each Node.list, fn node ->
                        #TODO: send new hall order to dist on other nodes 
                    end 
                
                    if order_belongs_to_me(floor, up?) do
                        Elevator.set_request(floor, %{true: 0, false: 1}[up?])
                    end
                    
                    pid = Process.spawn(__MODULE__.watchdog, {:new_hall_order, floor, up?})
                    active_orders = order_replace_at(active_orders, floor, up?, pid)
                end
            
                dist(active_orders)


            {:hall_order_finished, floor, up?} ->
                Enum.each Node.list, fn node ->
                    #TODO: send hall order finished to dist on other nodes 
                end 

                {active_orders, watchdog_pid} = order_finished(active_orders, floor, up?)
                Process.send(watchdog_pid, {:hall_order_done, floor, up?})

                dist(active_orders)
                
        end
    end


    def watchdog(floor, up?) do
        receive do
            {:hall_order_done, floor, up?} -> 
                Process.exit(self, :normal)
        after 
            @timeout -> #TODO: send new hall order to dist on self node 
        end
    end


    #Active hall order datatype, should be seperate module propably 
    #2D array (floor x button_type) of pids corresponding to watchdog process 

    def order_is_already_active?(active_orders, floor, up?) do
        #TODO
    end

    def order_replace_at(active_orders, floor, up?, value) do
        #TODO
    end

    def order_belongs_to_me(floor, up?) do
        #TODO: assignment part here
    end

    def order_finished(active_orders, floor, up?) do
        #TODO
    end
end
