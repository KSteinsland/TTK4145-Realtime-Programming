defmodule Requests do
    #TODO: update to new config enums 

    @button_map %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2}

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
            :dir_up ->
                cond do
                    request_above?() -> :dir_up
                    request_below?() -> :dir_down
                    true -> :dir_stop
                end

            direction when direction == :dir_down or direction == :dir_stop ->
                cond do
                    request_below?() -> :dir_down
                    request_above?() -> :dir_up
                    true -> :dir_stop
                end

            _ ->
                :dir_stop
        end
    end

    def should_stop? do
        req = Elevator.get_requests
        flr = Elevator.get_floor

        case Elevator.get_direction do
            :dir_down ->
                req |> Enum.at(flr) |> Enum.at(@button_map[:btn_hall_down]) > 0 or
                req |> Enum.at(flr) |> Enum.at(@button_map[:btn_cab]) > 0 or
                not request_below?()

            :dir_up ->
                req |> Enum.at(flr) |> Enum.at(@button_map[:btn_hall_up]) > 0 or
                req |> Enum.at(flr) |> Enum.at(@button_map[:btn_cab]) > 0 or
                not request_above?()

            _ ->
                true
        end
    end

    def clear_at_current_floor do
        #clear all variant for now
        Elevator.clear_all_requests_at_floor(Elevator.get_floor)
    end

end
