defmodule StateServer do
  use GenServer

  def init(_opts) do
    {:ok, %SystemState{}}
  end

  # client----------------------------------------
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
    # , debug: [:trace])
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  # calls----------------------------------------

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, state) do
    # Checks that all elevator states are valid before accecpting the new state
    # Could use some fixing
    valid =
      new_state.elevators
      |> Map.values()
      |> Enum.all?(fn elevator ->
        elevator == Elevator.new(elevator)
      end)

    if valid do
      {:reply, :ok, new_state}
    else
      {:reply, :error, state}
    end
  end
end
