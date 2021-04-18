defmodule AssignmentTest do
  use ExUnit.Case, async: false
  doctest Elevator

  test "test assignment1" do
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

    assert Assignment.assign(test_sys_state) == :"CJGasdZ@192.168.0.40"
  end

  test "test assignment2" do
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
          floor: 0,
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

    assert Assignment.assign(test_sys_state) == :"CJGXZ@192.168.0.40"
  end
end
