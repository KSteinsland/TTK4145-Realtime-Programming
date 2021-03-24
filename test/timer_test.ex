defmodule timerTest do
  use ExUnit.Case
  doctest timerTest


  setup do
    {:ok, pid} = Timer.start_link([])
    %{pid: pid}
  end

  test "timer" do
    assert Timer.timer_start(1_000) == :ok
    assert Timer.has_timed_out == false
    :timer.sleep(1000)
    assert Timer.has_timed_out == true
  end

  test "stop" do
    assert Timer.timer_start(1_000) == :ok
    assert Timer.has_timed_out == false
    assert Timer.timer_stop == :ok
    assert Timer.has_timed_out == true
  end

end
