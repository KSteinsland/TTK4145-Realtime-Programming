defmodule Elevator do
  @moduledoc """
    Elevator state.
  """

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @directions [:dir_up, :dir_down, :dir_stop]
  @behaviours [:be_idle, :be_door_open, :be_moving]
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)
  @btn_types Application.fetch_env!(:elevator_project, :button_types)
  @num_buttons length(@btn_types)
  @btn_values 0..1

  @type direction :: :dir_up | :dir_down | :dir_stop
  @type btn_type :: :btn_hall_up | :btn_hall_down | :btn_cab
  @type hall_btn_type :: :btn_hall_up | :btn_hall_down
  @type btn_value :: 0..1
  @type floor :: 0..unquote(@num_floors)
  @type behaviour :: :be_idle | :be_door_open | :be_moving
  @type req_list :: [[btn_value(), ...], ...]

  req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)

  defstruct floor: 0,
            direction: :dir_stop,
            requests: req_list,
            behaviour: :be_idle,
            counter: 0,
            active: true

  @type t :: %__MODULE__{
          floor: floor(),
          direction: direction(),
          requests: req_list(),
          behaviour: behaviour(),
          counter: pos_integer(),
          active: boolean()
        }

  @spec check(Elevator.t()) :: {:error, String.t()} | Elevator.t()
  @doc """
  Checks if the elevator struct is valid and returns elevator,
  If not, returns error
  """
  def check(%__MODULE__{} = elevator) do
    # elevator = struct(elevator, map)
    with {:ok, _floor} <- parse_floor(elevator.floor),
         {:ok, _direction} <- parse_direction(elevator.direction),
         {:ok, _requests} <- parse_requests(elevator.requests),
         {:ok, _behaviour} <- parse_behaviour(elevator.behaviour) do
      elevator
    else
      err -> err
    end
  end

  @spec update_requests(req_list(), floor(), btn_type(), btn_value()) ::
          req_list() | {:error, String.t()}
  @doc """
  Returns a request list `req` with the `value` set at `floor`, `btn_type`.
  """
  def update_requests(req, floor, btn_type, value) do
    with {:ok, _floor} <- parse_floor(floor),
         {:ok, _requests} <- parse_requests(req),
         {:ok, _btn_type} <- parse_btn_type(btn_type),
         {:ok, _btn_val} <- parse_btn_val(value) do
      {req_at_floor, _list} = List.pop_at(req, floor)
      updated_req_at_floor = List.replace_at(req_at_floor, @btn_types_map[btn_type], value)
      List.replace_at(req, floor, updated_req_at_floor)
    else
      err ->
        err
    end
  end

  @spec btn_types_map :: %{btn_cab: 2, btn_hall_down: 1, btn_hall_up: 0}
  def btn_types_map, do: @btn_types_map

  @spec btn_types :: [:btn_cab | :btn_hall_down | :btn_hall_up]
  def btn_types, do: @btn_types

  # guards-------------------------------------
  defp parse_floor(nil), do: {:error, "floor is required"}

  defp parse_floor(floor = :between_floors), do: {:ok, floor}

  defp parse_floor(floor) when floor in 0..@num_floors, do: {:ok, floor}

  defp parse_floor(_floor), do: {:error, "floor must be a valid floor"}

  defp parse_btn_type(btn_type) when btn_type in @btn_types, do: {:ok, btn_type}

  defp parse_btn_type(_invalid), do: {:error, "btn must be a valid atom"}

  defp parse_btn_val(btn_val) when btn_val in @btn_values, do: {:ok, btn_val}

  defp parse_btn_val(_invalid), do: {:error, "btn_val must be a valid button value"}

  defp parse_direction(nil), do: {:error, "direction is required"}

  defp parse_direction(direction) when direction in @directions, do: {:ok, direction}

  defp parse_direction(_invalid), do: {:error, "direction must be a valid atom"}

  defp parse_requests(nil), do: {:error, "requests are required"}

  defp parse_requests(requests)
       when is_list(requests) and length(requests) == @num_floors and
              length(hd(requests)) == @num_buttons do
    # Checking if all requests are in the valid buttons set
    valid_requests? =
      Enum.concat(requests)
      |> Enum.all?(fn btn ->
        btn in @btn_values
      end)

    if valid_requests? do
      {:ok, requests}
    else
      {:error, "requests must be a valid 2d list of size #{@num_floors}x#{@num_buttons}"}
    end
  end

  defp parse_requests(_invalid),
    do: {:error, "requests must be a valid 2d list of size #{@num_floors}x#{@num_buttons}"}

  defp parse_behaviour(nil), do: {:error, "behaviour is required"}

  defp parse_behaviour(behaviour) when behaviour in @behaviours, do: {:ok, behaviour}

  defp parse_behaviour(_invalid), do: {:error, "behaviour must be a valid atom"}
end
