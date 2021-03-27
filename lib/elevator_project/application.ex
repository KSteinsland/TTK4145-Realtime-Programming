defmodule ElevatorProject.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ElevatorProject.Worker.start_link(arg)
      # {ElevatorProject.Worker, arg}
      StateServer,
      Timer,
      {Driver, [{127, 0, 0, 1}, Application.fetch_env!(:elevator_project, :port_driver)]},
      ElevatorPoller,
      {NodeConnector, [33333, Random.gen_rand_str(5)]},
      Network
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElevatorProject.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # dev
  # def kill() do
  #   Process.exit(self(), :kill)
  # end
end
