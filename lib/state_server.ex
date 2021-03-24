defmodule Elevator.StateServer do
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
    case Elevator.new(new_state.elevators[:el1]) do #TODO make general
      {:error, msg} ->
        {:reply, {:error, msg}, state}

      _ ->
        {:reply, :ok, new_state}
    end
  end
end
