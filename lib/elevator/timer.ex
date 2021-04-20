defmodule Elevator.Timer do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, %{door: nil, move: nil}}
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # User API ----------------------------------------------

  @spec timer_start(pid(), integer(), :door | :move) :: :ok
  @doc """
  Starts a timer with duration "time" on the process on "pid". The timer will be identified as "timer".
  """
  def timer_start(pid, time, timer) do
    GenServer.cast(__MODULE__, {:timer_start, pid, time, timer})
  end

  @spec timer_stop(:door | :move) :: :ok
  @doc """
  Stops the timer identified as "timer".
  """
  def timer_stop(timer) do
    GenServer.call(__MODULE__, {:timer_stop, timer})
  end

  # Cast/calls  ----------------------------------------------

  def handle_cast({:timer_start, pid, time, timer}, state) do
    timer_ref = Map.get(state, timer)

    if timer_ref != nil do
      Process.cancel_timer(timer_ref)
    end

    timer_ref = Process.send_after(pid, {:timed_out, timer}, time)
    {:noreply, Map.put(state, timer, timer_ref)}
  end

  def handle_call({:timer_stop, timer}, _from, state) do
    timer_ref = Map.get(state, timer)

    if timer_ref != nil do
      Process.cancel_timer(timer_ref)
    end

    {:reply, :ok, Map.put(state, timer, timer_ref)}
  end
end
