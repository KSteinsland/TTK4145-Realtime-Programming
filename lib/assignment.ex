defmodule Assigment do
  @behavior_map %{be_moving: "moving", be_idle: "idle", be_door_open: "doorOpen"}
  @dir_map %{dir_up: "up", dir_down: "down", dir_stop: "stop"}

  def assign(sys_state) do
    states =
      Enum.reduce(sys_state.elevators, %{}, fn {id, el}, acc ->
        cab_reqs = Enum.map(el.requests, fn [_, _, c] -> %{0 => false, 1 => true}[c] end)

        Map.put(acc, id, %{
          behaviour: @behavior_map[el.behaviour],
          floor: el.floor,
          direction: @dir_map[el.direction],
          cabRequests: cab_reqs
        })
      end)

    hall_requests =
      Enum.reduce(sys_state.hall_requests.hall_orders, [], fn [one, two], acc ->
        m1 = %{new: true}
        m2 = %{nil: false, true: true}
        acc ++ [[m2[m1[one]], m2[m1[two]]]]
      end)

    sys_map = %{hallRequests: hall_requests, states: states}
    {:ok, json_in} = JSON.encode(sys_map)

    {:ok, dir_path} = File.cwd()
    script_path = Path.join(dir_path, "assignment/run.sh")
    {json_out, _} = System.cmd(script_path, [json_in])

    {:ok, el_map} = JSON.decode(json_out)

    winner_map = Enum.reduce(el_map, %{}, fn {el_id, list}, winner_map ->
      if Enum.reduce(List.flatten(list), false, fn bool, acc -> bool or acc end) do
        Map.put(winner_map, :winner, el_id)
      else
        winner_map
      end
    end)

    winner_map[:winner]
  end

  def test_assign() do
    test_sys_state = %StateServer.SystemState{
      elevators: %{
        "CJGXZ@192.168.0.40": %Elevator{
          active: true,
          behaviour: :be_moving,
          counter: 3,
          direction: :dir_stop,
          floor: 1,
          requests: [[0, 0, 0], [0, 0, 0], [0, 1, 0], [0, 0, 0]]
        },
        "CJGasdZ@192.168.0.40": %Elevator{
          active: true,
          behaviour: :be_moving,
          counter: 3,
          direction: :dir_stop,
          floor: 2,
          requests: [[0, 0, 0], [0, 0, 0], [0, 1, 0], [0, 0, 0]]
        }
      },
      hall_requests: %StateServer.HallRequests{
        hall_orders: [
          [:done, :done],
          [:done, :done],
          [:done, :new],
          [:done, :done]
        ]
      }
    }

    assign(test_sys_state)
  end
end
