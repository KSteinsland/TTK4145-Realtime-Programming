defmodule timerTest do
  use ExUnit.Case
  doctest timerTest


  setup do
    {:ok, pid} = Timer.start_link([])
    %{pid: pid}
  end

  test "timer" do
    assert Timer.timer_start(1_000) == :ok
    assert Timer.has_timed_out == 0
    :timer.sleep(1000)
    assert Timer.has_timed_out == 1
  end

  test "stop" do
    assert Timer.timer_start(1_000) == :ok
    assert Timer.has_timed_out == 0
    assert Timer.timer_stop == :ok
    assert Timer.has_timed_out == 1
  end

end
