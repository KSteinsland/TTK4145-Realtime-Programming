defmodule Assigment do
  @behavior_map %{be_moving: "moving", be_idle: "idle", be_door_open: "doorOpen"}

  def assign(sys_state) do
    {:ok, dir_path} = File.cwd()
    script_path = Path.join(dir_path, "/assignment/run.sh")

    states =
      Enum.reduce(sys_state.elevators, [], fn {id, el}, acc ->
        cab_reqs = Enum.map(el.requests, fn [_, _, c] -> %{0 => false, 1 => true}[c] end)

        m =
          Map.new([
            {id,
             %{behaviour: @behavior_map[el.behaviour], floor: el.floor, cabRequests: cab_reqs}}
          ])

        acc ++ [m]
      end)

    hall_requests =
      Enum.reduce(sys_state.hall_requests.hall_orders, [], fn [one, two], acc ->
        m1 = %{assigned: true}
        m2 = %{nil: false, true: true}
        acc ++ [[m2[m1[one]], m2[m1[two]]]]
      end)

    sys_map = %{hallRequests: hall_requests, states: states}

    {:ok, json} = JSON.encode(sys_map)

    System.cmd("bash", [script_path, json])
  end

  def test_assing() do
    test_sys_state = %StateServer.SystemState{
      elevators: %{
        "CJGXZ@192.168.0.40": %Elevator{
          active: true,
          behaviour: :be_moving,
          counter: 3,
          direction: :dir_stop,
          floor: 2,
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
          [:done, :assigned],
          [:done, :done]
        ]
      }
    }

    assign(test_sys_state)
  end
end
