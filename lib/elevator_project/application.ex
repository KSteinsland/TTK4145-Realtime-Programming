defmodule ElevatorProject.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    load_system_env()

    children = [
      MasterStarter,
      {NodeConnector, [33333, Application.get_env(:elevator_project, :name)]},
      StateServer,
      Elevator.Supervisor
    ]

    opts = [strategy: :one_for_one, name: ElevatorProject.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_system_env() do
    # export VAR=VAL

    case System.get_env("EL_DRIVER_PORT") do
      nil ->
        :ok

      value ->
        driver_port = String.to_integer(value)
        Application.put_env(:elevator_project, :port_driver, driver_port)
    end

    case System.get_env("NODE_NAME") do
      nil ->
        Application.put_env(:elevator_project, :name, Utils.Random.gen_rand_str(5))

      name_str ->
        Application.put_env(:elevator_project, :name, name_str)
    end
  end
end
