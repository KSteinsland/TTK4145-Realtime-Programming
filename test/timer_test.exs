defmodule TimerTest do
  use ExUnit.Case
  doctest Timer

  setup_all do
    {:ok, pid} = Timer.start_link([])
    %{pid: pid}
  end

  test "timer" do
    assert Timer.timer_start(1_000) == :ok
    assert Timer.has_timed_out() == false
    Timer.timer_start(1_000)
    :timer.sleep(1500)
    assert Timer.has_timed_out() == true
  end

  test "stop" do
    Timer.timer_start(1_000)
    :timer.sleep(1500)
    assert Timer.has_timed_out() == true
    assert Timer.timer_stop() == :ok
    Timer.timer_start(1_000)
    Timer.timer_stop()
    assert Timer.has_timed_out() == false
  end
end
