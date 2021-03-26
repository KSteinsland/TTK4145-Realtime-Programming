defmodule Requests do
  @moduledoc """
  Pure functions that operate on elevator struct
  """

  @button_map Application.fetch_env!(:elevator_project, :button_map)
  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
  @hall_btn_map Application.compile_env(:elevator_project, :button_map)
  @hall_btn_types Map.keys(@hall_btn_map)

  @doc """
  Returns bool ':true' if there is a request above current floor. 'false' if not.
  """
  def request_above?(%Elevator{} = elevator) do
    {_below, above} = elevator.requests |> Enum.split(elevator.floor + 1)
    above |> List.flatten() |> Enum.sum() > 0
  end

  @doc """
  Returns bool ':true' if there is a request below current floor. 'false' if not.
  """
  def request_below?(%Elevator{} = elevator) do
    {below, _above} = elevator.requests |> Enum.split(elevator.floor)
    below |> List.flatten() |> Enum.sum() > 0
  end

  @doc """
  Returns direction ':dir_up', ':dir_down' or ':dir_stop' based on current
  traveling direction and whether or not there are orders above or below.
  Will continue in same direction when possible.
  """
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

  @doc """
  Returns bool ':true' or ':false' on wheter the elevator should stop.
  Stops if there is an hall order that matches direction, a cab order or no more
  orders in direction of travel.
  """
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

  @doc """
  Returns a new elevator struct with a orders at current floor set to zero.
  Uses the clear all variant of order behaviour.
  """
  def clear_at_current_floor(%Elevator{} = elevator) do
    b_req = List.duplicate(0, @num_buttons)
    req = List.replace_at(elevator.requests, elevator.floor, b_req)
    %Elevator{elevator | requests: req}
  end

end
