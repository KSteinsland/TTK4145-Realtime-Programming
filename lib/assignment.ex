defmodule Assignment do
  @behavior_map %{be_moving: "moving", be_idle: "idle", be_door_open: "doorOpen"}
  @dir_map %{dir_up: "up", dir_down: "down", dir_stop: "stop"}



  def assign(sys_state, parent) do
    sys_state_formated = format_sys_state(sys_state)
    {:ok, json_in} = JSON.encode(sys_state_formated)

    json_out = call_assigner(json_in)
    {:ok, el_map} = JSON.decode(json_out)

    winner = extract_winner(el_map)

    send(parent, {:ok, String.to_atom(winner)})
  end

  def extract_winner(elevator_map) do
    Enum.reduce(elevator_map, %{}, fn {el_id, list}, winner_map ->
      if Enum.reduce(List.flatten(list), false, fn bool, acc -> bool or acc end) do
        Map.put(winner_map, :winner, el_id)
      else
        winner_map
      end
    end)[:winner]
  end

  def format_sys_state(sys_state) do
    states =
      Enum.reduce(sys_state.elevators, %{}, fn {id, el}, acc ->
        cab_reqs = Enum.map(el.requests, fn [_, _, c] -> %{0 => false, 1 => true}[c] end)

        if el.active do
          Map.put(acc, id, %{
            behaviour: @behavior_map[el.behaviour],
            floor: el.floor,
            direction: @dir_map[el.direction],
            cabRequests: cab_reqs
          })
        else
          acc
        end
      end)

    hall_requests =
      Enum.reduce(sys_state.hall_requests.hall_orders, [], fn [one, two], acc ->
        m1 = %{new: true}
        m2 = %{nil: false, true: true}
        acc ++ [[m2[m1[one]], m2[m1[two]]]]
      end)

    %{hallRequests: hall_requests, states: states}
  end

  defp call_assigner(json_in) do
    # Calls the correct assigner executable based on OS

    # We might need to change some of these options, especially clearRequestType
    # %{travelDuration: 2500, doorOpenDuration: 3000}
    opts = %{}
    # --travelDuration : Travel time between two floors in milliseconds (default 2500)
    # --doorOpenDuration : Door open time in milliseconds (default 3000)
    # --clearRequestType : When stopping at a floor, clear either all requests or only those inDirn (default)
    # --includeCab : Includes the cab requests in the output. The output becomes a 3xN boolean matrix for each elevator ([[up-0, down-0, cab-0], [...],...]). (disabled by default)

    case :os.type() do
      {:unix, os} ->
        os = if os == :linux, do: to_string(os), else: "mac"
        IO.puts("Calling #{os} assigner")

        {:ok, dir_path} = File.cwd()
        assigner_path = Path.join(dir_path, "assignment/#{os}/hall_request_assigner")

        {json_out, _} = System.cmd(assigner_path, ["-i", json_in | get_extra_opts(opts)])

        json_out

      {:win32, _} ->
        # IO.puts("Calling windows assigner")

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

  def test_assignmenet() do
    #this input will generate bug, TODO fix bug
    test_sys_state = %StateServer.SystemState{
      elevators: %{
        "HPFND@192.168.0.40": %Elevator{
          active: false,
          behaviour: :be_idle,
          counter: 14,
          direction: :dir_stop,
          floor: 2,
          requests: [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]
        }
      },
      hall_requests: %StateServer.HallRequests{
        hall_orders: [[:new, :done], [:done, :done], [:done, :done], [:done, :done]]
      }
    }

    assign(test_sys_state, self())

    receive do
      {:ok, winner} -> winner
    end
  end
end
