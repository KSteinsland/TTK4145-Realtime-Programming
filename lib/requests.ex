defmodule Requests do
    #TODO: update to new config enums 

    @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
    
    def request_above? do
        {_below, above} = Elevator.get_requests |> Enum.split(Elevator.get_floor+1) 
        above |> List.flatten |> Enum.sum > 0
    end

    def request_below? do
        {below, _above} = Elevator.get_requests |> Enum.split(Elevator.get_floor)
        below |> List.flatten |> Enum.sum > 0
    end
    
    def choose_direction do
        case Elevator.get_direction do
            :El_up -> 
                cond do 
                    request_above? -> :El_up
                    request_below? -> :El_down
                    true -> :El_stop
                end

            :El_stop -> 
                cond do 
                    request_below? -> :El_down
                    request_above? -> :El_up
                    true -> :El_stop
                end
            _ -> 
                :El_stop  
        end
    end

    def should_stop? do
        req = Elevator.get_requests
        flr = Elevator.get_floor

        case Elevator.get_direction do
            :El_down -> 
                Enum.at(req, flr, @button_map[:hall_down]) or 
                Enum.at(req, flr, @button_map[:cab]) or 
                not request_below? 

            :El_up -> 
                Enum.at(req, flr, @button_map[:hall_up]) or 
                Enum.at(req, flr, @button_map[:cab]) or 
                not request_above? 
            
            _ -> 
                true
        end
    end

    def clear_at_current_floor do
        #clear all variant for now
        Elevator.clear_all_requests_at_floor(Elevator.get_floor)
    end

end