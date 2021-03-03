defmodule Timer do
  use GenServer
  require Kernel

  def start_link [] do
    GenServer.start_link(__MODULE__, {nil, 0}, name: __MODULE__)
  end

  def init {timer, timed_out} do
    {:ok, {timer, timed_out}}
  end

  def stop do
    GenServer.stop __MODULE__
  end

  # User API ----------------------------------------------

  def timer_start time do
    GenServer.cast __MODULE__, {:timer_start, time}
  end

  def timer_stop do
    GenServer.call __MODULE__, :timer_stop
  end

  def has_timed_out do
    GenServer.call __MODULE__, :has_timed_out
  end


  # Cast/calls  ----------------------------------------------

  def handle_cast {:timer_start, time}, state do
    {timer, timed_out} = state
    timer = Process.send_after(self(), {:timed_out, 1}, time)
    {:noreply, {timer, 0}}
  end

  def handle_info {:timed_out, bool}, state do
    {timer, timed_out} = state
    {:noreply, {timer, bool}}
  end

  def handle_call :timer_stop, _from, state do
    {timer, timed_out} = state
    if (timer != nil) do
      Process.cancel_timer timer
    end
    {:reply, :ok, {timer, 0}}
  end

  def handle_call :has_timed_out, _from, state do
    {timer, timed_out} = state
    {:reply, timed_out, state}
  end

end
