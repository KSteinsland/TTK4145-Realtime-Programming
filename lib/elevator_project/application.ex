defmodule ElevatorProject.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # dev
    # check if EL_DRIVER_PORT env variable is set and if so, load it
    load_system_env()

    children = [
      # Starts a worker by calling: ElevatorProject.Worker.start_link(arg)
      # {ElevatorProject.Worker, arg}
      MasterStarter,
      {NodeConnector, [33333, Utils.Random.gen_rand_str(5)]},
      ElServer,
      ElevatorSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElevatorProject.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # dev
  defp load_system_env() do
    driver_port =
      case System.get_env("EL_DRIVER_PORT") do
        nil -> Application.fetch_env!(:elevator_project, :port_driver)
        value -> String.to_integer(value)
      end

    Application.put_env(:elevator_project, :port_driver, driver_port)
  end
end
