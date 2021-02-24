require Driver
#require Elevator


defmodule FSM do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(opts \\ []) do
    state = {:elevator, :elevator_out}
    {:ok, state}
  end

  def on_init_between_floors(serverpid) do
    GenServer.cast(serverpid, :on_init_between_floors)
  end






  def handle_cast({:on_init_betwwen_floors}, state) do
    {:elevator, :elevator_out} = state

    Driver.set_motor_direction(:down)
    Elevator.set_dir(Elevator, :down)
    Elevator.set_behaviour(Elevator, El_moving)

    # outputDevice.motorDirection(D_Down);
    # elevator.dirn = D_Down;
    # elevator.behaviour = EB_Moving;
  end

end
