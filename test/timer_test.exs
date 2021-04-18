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
    assert Timer.timer_start(self(), 1_00) == :ok
    assert_receive :timed_out, 2_00
  end

  test "stop" do
    Timer.timer_start(self(), 1_00)

    assert_receive :timed_out, 2_00
    assert Timer.timer_stop() == :ok
    Timer.timer_start(self(), 1_00)
    Timer.timer_stop()

    receive do
      msg ->
        assert false
    after
      2_00 ->
        assert true
    end
  end
end
