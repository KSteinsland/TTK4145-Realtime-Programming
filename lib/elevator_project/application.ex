defmodule ElevatorProject.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # check if EL_DRIVER_PORT env variable is set and if so, load it
    load_system_env()

    children = [
      MasterStarter,
      {NodeConnector, [33333, Utils.Random.gen_rand_str(5)]},
      StateServer,
      ElevatorSupervisor
    ]

    opts = [strategy: :one_for_one, name: ElevatorProject.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_system_env() do
    driver_port =
      case System.get_env("EL_DRIVER_PORT") do
        nil -> Application.fetch_env!(:elevator_project, :port_driver)
        value -> String.to_integer(value)
      end

    Application.put_env(:elevator_project, :port_driver, driver_port)
  end
end
