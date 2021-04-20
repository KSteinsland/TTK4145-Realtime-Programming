defmodule ElServer do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %Elevator{}}
  end

  def get_elevator() do
    GenServer.call(__MODULE__, :get_elevator)
  end

  def set_elevator(elevator) do
    case Elevator.check(elevator) do
      {:error, msg} ->
        {:error, msg}

      {:ok, ^elevator} ->
        GenServer.cast(__MODULE__, {:set_elevator, elevator})
        :ok
    end
  end

  def node_active(bool) do
    GenServer.cast(__MODULE__, {:node_active, bool})
  end

  def handle_cast({:set_elevator, elevator_new}, _elevator) do
    {:noreply, elevator_new}
  end

  def handle_cast({:node_active, bool}, elevator) do
    elevator = %{elevator | active: bool}
    {:noreply, elevator}
  end

  def handle_call(:get_elevator, _from, elevator) do
    {:reply, elevator, elevator}
  end
end
