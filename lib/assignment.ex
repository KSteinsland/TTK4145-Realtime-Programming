defmodule Assignment do
  @moduledoc """
  Calculates which elevator should be assigned to which hall order.
  Uses cost function from https://github.com/TTK4145/Project-resources/tree/master/cost_fns/hall_request_assigner
  """
  @behavior_map %{be_moving: "moving", be_idle: "idle", be_door_open: "doorOpen"}
  @dir_map %{dir_up: "up", dir_down: "down", dir_stop: "stop"}

  @spec assign(atom | %{:elevators => any, :hall_requests => any, optional(any) => any}) :: atom
  @doc """
  Takes in a system state struct with a new hall order,
  returns which elevator should take the order.
  """
  def assign(sys_state) do
    sys_state_formated = format_sys_state(sys_state)
    {:ok, json_in} = JSON.encode(sys_state_formated)

    json_out = call_assigner(json_in)
    {:ok, el_map} = JSON.decode(json_out)

    winner = extract_winner(el_map)

    String.to_atom(winner)
  end

  defp extract_winner(elevator_map) do
    Enum.reduce(elevator_map, %{}, fn {el_id, list}, winner_map ->
      if Enum.reduce(List.flatten(list), false, fn bool, acc -> bool or acc end) do
        Map.put(winner_map, :winner, el_id)
      else
        winner_map
      end
    end)[:winner]
  end

  defp format_sys_state(sys_state) do
    elevators = Enum.filter(sys_state.elevators, fn {_id, el} -> el.active end)

    elevators =
      if elevators == [] do
        sys_state.elevators
      else
        elevators
      end

    states =
      Enum.reduce(elevators, %{}, fn {id, el}, acc ->
        cab_reqs = Enum.map(el.requests, fn [_, _, c] -> %{0 => false, 1 => true}[c] end)

        Map.put(acc, id, %{
          behaviour: @behavior_map[el.behaviour],
          floor: el.floor,
          direction: @dir_map[el.direction],
          cabRequests: cab_reqs
        })
      end)

    hall_requests =
      Enum.reduce(sys_state.hall_requests, [], fn [one, two], acc ->
        m1 = %{new: true}
        m2 = %{nil: false, true: true}
        acc ++ [[m2[m1[one]], m2[m1[two]]]]
      end)

    %{hallRequests: hall_requests, states: states}
  end

  defp call_assigner(json_in) do
    opts = %{}

    case :os.type() do
      {:unix, os} ->
        os = if os == :linux, do: to_string(os), else: "mac"
        {:ok, dir_path} = File.cwd()
        assigner_path = Path.join(dir_path, "assignment/#{os}/hall_request_assigner")
        {json_out, _} = System.cmd(assigner_path, ["-i", json_in | get_extra_opts(opts)])
        json_out

      {:win32, _} ->
        {:ok, dir_path} = File.cwd()
        assigner_path = Path.join(dir_path, "assignment/windows/hall_request_assigner.exe")
        {json_out, _} = System.cmd(assigner_path, ["-i", json_in | get_extra_opts(opts)])
        json_out
    end
  end

  defp get_extra_opts(opts) do
    opts
    |> Enum.reduce([], fn {key, val}, acc -> ["--" <> to_string(key), to_string(val) | acc] end)
  end
end
