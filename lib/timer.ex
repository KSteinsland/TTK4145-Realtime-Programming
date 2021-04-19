defmodule Timer do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, nil}
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # TODO make task supervisor
  # and link calling pid to task

  # User API ----------------------------------------------

  def timer_start(pid, time) do
    GenServer.cast(__MODULE__, {:timer_start, pid, time})
  end

  def timer_stop do
    GenServer.call(__MODULE__, :timer_stop)
  end

  # Cast/calls  ----------------------------------------------

  def handle_cast({:timer_start, pid, time}, state) do
    timer = state

    if timer != nil do
      Process.cancel_timer(timer)
    end

    timer = Process.send_after(pid, :timed_out, time)
    {:noreply, timer}
  end

  def handle_call(:timer_stop, _from, state) do
    timer = state

    if timer != nil do
      Process.cancel_timer(timer)
    end

    {:reply, :ok, timer}
  end
end
