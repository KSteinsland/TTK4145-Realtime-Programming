defmodule ElevatorSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Timer,
      {Driver, [{127, 0, 0, 1}, Application.fetch_env!(:elevator_project, :port_driver)]},
      ElevatorController,
      HardwarePoller
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
