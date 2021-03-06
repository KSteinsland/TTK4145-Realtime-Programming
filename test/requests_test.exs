defmodule RequestsTest do
    use ExUnit.Case
    doctest Elevator

    setup do
        {:ok, pid} = Elevator.start_link([])
        %{pid: pid}
    end

    test "requests above/below" do
        assert Elevator.set_floor(1) == :ok
        assert Requests.request_above? == false
        assert Requests.request_below? == false

        assert Elevator.set_request(1, 1) == :ok
        assert Requests.request_above? == false
        assert Requests.request_above? == false

        assert Elevator.set_request(2, 1) == :ok
        assert Requests.request_above? == true
        assert Requests.request_below? == false

        assert Elevator.set_floor(3) == :ok
        assert Requests.request_above? == false
        assert Requests.request_below? == true
    end

  end
