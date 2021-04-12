defmodule Elevator do
  @moduledoc """
    Elevator state.
  """

  @num_floors Application.fetch_env!(:elevator_project, :num_floors)
  @num_buttons Application.fetch_env!(:elevator_project, :num_buttons)
  @directions Application.fetch_env!(:elevator_project, :directions)
  @behaviours Application.fetch_env!(:elevator_project, :behaviours)
  @btn_types_map Application.fetch_env!(:elevator_project, :button_map)
  @btn_types Map.keys(@btn_types_map)
  @btn_values [0, 1]

  req_list = List.duplicate(0, @num_buttons) |> List.duplicate(@num_floors)

  @type directions :: :dir_up | :dir_down | :dir_stop
  @type btn_types :: :btn_hall_up | :btn_hall_down | :btn_cab
  @type behaviours :: :be_idle | :be_door_open | :be_moving

  # Feels bad to have counter here, but is the easiest solution
  defstruct floor: 0, direction: :dir_stop, requests: req_list, behaviour: :be_idle, counter: 0

  @type t :: %__MODULE__{
          floor: pos_integer(),
          direction: directions(),
          requests: list(),
          behaviour: behaviours()
        }

  def new(%__MODULE__{} = elevator \\ %__MODULE__{}) do
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

  # guards-------------------------------------
  defp parse_floor(nil), do: {:error, "floor is required"}

  defp parse_floor(floor = :between_floors), do: {:ok, floor}

  defp parse_floor(floor) when is_integer(floor) and floor < @num_floors and floor >= 0,
    do: {:ok, floor}

  defp parse_floor(_invalid), do: {:error, "floor must be a integer in range [0, #{@num_floors})"}

  defp parse_direction(nil), do: {:error, "direction is required"}

  defp parse_direction(direction) when is_atom(direction) and direction in @directions,
    do: {:ok, direction}

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

  defp parse_behaviour(behaviour) when is_atom(behaviour) and behaviour in @behaviours,
    do: {:ok, behaviour}

  defp parse_behaviour(_invalid), do: {:error, "behaviour must be a valid atom"}

  # util----------------------------------------
  def update_requests(req, floor, btn_type, value)
      when is_integer(floor) and floor >= 0 and btn_type in @btn_types and is_list(req) and
             value in @btn_values do
    {req_at_floor, _list} = List.pop_at(req, floor)
    updated_req_at_floor = List.replace_at(req_at_floor, @btn_types_map[btn_type], value)
    List.replace_at(req, floor, updated_req_at_floor)
  end

  def update_requests(_req, _floor, _btn_type, _value) do
    {:error, "value is not valid"}
  end
end
