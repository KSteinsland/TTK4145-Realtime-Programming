defmodule TimerTest do
  use ExUnit.Case, async: false
  doctest Timer

  setup do
    case Timer.start_link([]) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _}} ->
        :ok
    end
  end

  test "timer" do
    assert Timer.timer_start(1_00) == :ok
    assert Timer.has_timed_out() == false
    Timer.timer_start(1_00)
    Process.sleep(1_50)
    assert Timer.has_timed_out() == true
  end

  test "stop" do
    Timer.timer_start(1_00)
    Process.sleep(1_50)
    assert Timer.has_timed_out() == true
    assert Timer.timer_stop() == :ok
    Timer.timer_start(1_00)
    Timer.timer_stop()
    assert Timer.has_timed_out() == false
  end
end
