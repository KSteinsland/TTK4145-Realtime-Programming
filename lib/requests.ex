defmodule Requests do
  # TODO: update to new config enums

  @button_map %{:btn_hall_up => 0, :btn_hall_down => 1, :btn_cab => 2}

  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)

  defp request_above?(%Elevator{} = elevator) do
    {_below, above} = elevator.requests |> Enum.split(elevator.floor + 1)
    above |> List.flatten() |> Enum.sum() > 0
  end

  defp request_below?(%Elevator{} = elevator) do
    {below, _above} = elevator.requests |> Enum.split(elevator.floor)
    below |> List.flatten() |> Enum.sum() > 0
  end

  def choose_direction(%Elevator{} = elevator) do
    case elevator.direction do
      :dir_up ->
        cond do
          request_above?(elevator) -> :dir_up
          request_below?(elevator) -> :dir_down
          true -> :dir_stop
        end

      direction when direction == :dir_down or direction == :dir_stop ->
        cond do
          request_below?(elevator) -> :dir_down
          request_above?(elevator) -> :dir_up
          true -> :dir_stop
        end

      _ ->
        :dir_stop
    end
  end

  def should_stop?(%Elevator{} = elevator) do
    req = elevator.requests
    flr = elevator.floor

    case elevator.direction do
      :dir_down ->
        req |> Enum.at(flr) |> Enum.at(@button_map[:btn_hall_down]) > 0 or
          req |> Enum.at(flr) |> Enum.at(@button_map[:btn_cab]) > 0 or
          not request_below?(elevator)

      :dir_up ->
        req |> Enum.at(flr) |> Enum.at(@button_map[:btn_hall_up]) > 0 or
          req |> Enum.at(flr) |> Enum.at(@button_map[:btn_cab]) > 0 or
          not request_above?(elevator)

      _ ->
        true
    end
  end

  def clear_at_current_floor(%Elevator{} = elevator) do
    # clear all variant for now

    b_req = List.duplicate(0, @num_buttons)
    req = List.replace_at(elevator.requests, elevator.floor, b_req)
    # state = %{state | requests: req}
    # maybe change this to only return requests?
    %Elevator{elevator | requests: req}
  end
end
