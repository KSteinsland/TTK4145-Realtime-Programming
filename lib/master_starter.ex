defmodule MasterStarter do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end

  def upgrade_to_master() do
    case Supervisor.start_child(MasterStarter, MasterSupervisor) do
      {:error, :already_present} ->
        if Process.whereis(MasterSupervisor) == nil do
          Supervisor.restart_child(MasterStarter, MasterSupervisor)
        else
          :ok
        end

      {:ok, _} ->
        :ok
    end
  end

  def downgrade_to_slave() do
    Supervisor.terminate_child(MasterStarter, MasterSupervisor)
  end
end
