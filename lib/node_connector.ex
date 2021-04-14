defmodule NodeConnector do
  @moduledoc """
  Connects the nodes and keeps track of who is master.
  """
  use GenServer

  @broadcast_ip {255, 255, 255, 255}
  # dev
  # need port_range to run multiple nodes on a computer
  @port_range Application.compile_env!(:elevator_project, :local_nodes)
  @sleep_time trunc(Application.compile_env!(:elevator_project, :broadcast_ms) / @port_range)
  @timeout_time Application.compile_env!(:elevator_project, :master_timeout_ms)

  defmodule State do
    defstruct socket: nil,
              port: nil,
              # dev
              start_port: nil,
              name: :nonode@nohost,
              role: :slave,
              up_since: nil,
              watchdog: nil,
              master: nil,
              slaves: %{},
              # dev
              test_disconnected: false
  end

  def start_link([]) do
    start_link([33333, "Elevator"])
  end

  def start_link([start_port, name]) do
    GenServer.start_link(__MODULE__, [start_port, name], name: __MODULE__)
  end

  ## client ------------------------------------------

  def wait_for_node_startup() do
    # Ensures that we do not register :nonode@nohost in the elevator map
    if get_self() == :nonode@nohost do
      Process.sleep(10)
      wait_for_node_startup()
    end
  end

  def get_all_slaves() do
    GenServer.call(__MODULE__, :get_all_slaves)
  end

  def get_self() do
    GenServer.call(__MODULE__, :get_self)
  end

  def get_role do
    GenServer.call(__MODULE__, :get_role)
  end

  def get_master do
    GenServer.call(__MODULE__, :get_master)
  end

  # debug
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # debug
  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  ## server ------------------------------------------

  def init([start_port, name]) do
    # dev
    # port = start_port
    # {:ok, socket} = :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}])
    {:ok, socket, port} = dev_try_create_socket(start_port, start_port + @port_range)
    name = dev_register_node(name)

    {:ok,
     %State{
       socket: socket,
       port: port,
       start_port: start_port,
       name: name,
       up_since: System.os_time(:millisecond),
       watchdog: start_watchdog()
     }}
  end

  # calls ------------------------------------------

  def handle_call(:get_all_slaves, _from, state) do
    {:reply, state.slaves, state}
  end

  def handle_call(:get_self, _from, state) do
    {:reply, state.name, state}
  end

  def handle_call(:get_role, _from, state) do
    {:reply, state.role, state}
  end

  def handle_call(:get_master, _from, state) do
    {:reply, state.master, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, _state) do
    {:reply, :ok, new_state}
  end

  def handle_call(:dev_reconnect, _from, state) do
    Node.start(state.name, :longnames)
    Node.set_cookie(:choc)

    state = %State{state | test_disconnected: false}

    if state.role == :master do
      send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
    end

    {:reply, :ok, state}
  end

  # info ------------------------------------------

  def handle_info(:timed_out, state) do
    if state.role != :master do
      IO.puts("Master timed out, upgrading self to master")

      MasterSupervisor.upgrade_to_master()

      state = %State{state | role: :master, master: Node.self()}
      send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  # dev
  # def handle_info(:loop_master, state) do
  def handle_info({:loop_master, start_port, end_port}, state) do
    if state.role == :master and not state.test_disconnected do
      :gen_udp.send(state.socket, @broadcast_ip, start_port, "#{Node.self()}_#{state.up_since}")

      # dev
      # if Integer.mod(start_port, end_port) == 0, do: IO.puts("sending udp")
      new_port = fn start_port, end_port ->
        if start_port == end_port do
          start_port - @port_range
        else
          start_port + 1
        end
      end

      Process.send_after(
        self(),
        # dev
        # :loop_master
        {:loop_master, new_port.(start_port, end_port), end_port},
        @sleep_time
      )

      {:noreply, state}
    else
      # stop looping!
      {:noreply, state}
    end
  end

  def handle_info({:udp, _socket, _host, _port, packet}, state) do
    [full_name | [up_since | _]] = String.split(to_string(packet), "_")
    up_since = String.to_integer(up_since)

    latest_master = String.to_atom(full_name)

    if not state.test_disconnected do
      if state.role == :slave do
        master =
          case state.master do
            ^latest_master ->
              state.master

            _ ->
              # catches both when state.master = nil
              # and when state.master is outdated
              IO.puts("Found master #{full_name}!")

              connect_to_master(latest_master, state.up_since)

              latest_master
          end

        {:noreply, %State{state | watchdog: restart_watchdog(state.watchdog), master: master}}
      else
        # handles case when there are multiple masters

        if up_since < state.up_since do
          # downgrade to slave
          IO.puts("Downgrading to slave")
          IO.puts("#{full_name} is the master")

          MasterSupervisor.downgrade_to_slave()

          master = String.to_atom(full_name)
          connect_to_master(master, up_since)

          {:noreply,
           %State{
             state
             | role: :slave,
               slaves: %{},
               watchdog: restart_watchdog(state.watchdog),
               master: master
           }}
        else
          # do nothing, we are the "first" master and the other node should downgrade
          {:noreply, state}
        end
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:slave_connected, node_name, up_since}, state) do
    IO.puts("Slave #{node_name} connected!")

    StateDistribution.update_requests(node_name)
    StateDistribution.update_node(node_name)
    StateDistribution.node_active(node_name, true)

    Node.monitor(node_name, true)
    new_slaves = Map.put(state.slaves, node_name, up_since)
    send({__MODULE__, node_name}, {:slaves, new_slaves})
    {:noreply, %State{state | slaves: new_slaves}}
  end

  def handle_info({:slaves, slaves}, state) do
    {:noreply, %State{state | slaves: slaves}}
  end

  def handle_info({:nodedown, node}, state) do
    IO.puts("Lost connection to node #{node}!")
    # name = node |> to_string() |> String.split("@") |> Enum.at(0)

    StateDistribution.node_active(node, false)

    # upgrade to master if master disconnected
    case state.master do
      ^node ->
        if state.up_since <= state.slaves |> Map.values() |> Enum.min() do
          IO.puts("Master disconnected, upgrading self to master")

          MasterSupervisor.upgrade_to_master()

          state = %State{
            state
            | watchdog: stop_watchdog(state.watchdog),
              role: :master,
              master: Node.self(),
              slaves: Map.delete(state.slaves, Node.self())
          }

          send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
          {:noreply, state}
        else
          # somebody else should become master
          {:noreply, %{state | watchdog: restart_watchdog(state.watchdog)}}
        end

      master ->
        {:noreply, %{state | master: master, slaves: Map.delete(state.slaves, node)}}
    end
  end

  def handle_info(:shutdown, state) do
    :gen_udp.close(state.socket)
    Process.exit(self(), :kill)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    # Catches all invalid messages
    IO.inspect("Invalid Message: ")
    IO.inspect(msg)
    {:noreply, state}
  end

  # Utils ------------------------------------------

  defp connect_to_master(master, up_since) do
    Node.monitor(master, true)
    Node.connect(master)
    send({__MODULE__, master}, {:slave_connected, Node.self(), up_since})
  end

  defp start_watchdog() do
    Process.send_after(self(), :timed_out, @timeout_time)
  end

  defp restart_watchdog(timer) do
    if timer != nil do
      Process.cancel_timer(timer)
    end

    Process.send_after(self(), :timed_out, @timeout_time)
  end

  defp stop_watchdog(timer) do
    if timer != nil do
      Process.cancel_timer(timer)
    end

    nil
  end

  # Dev ------------------------------------------

  defp dev_register_node(name) do
    if Node.self() == :nonode@nohost do
      {:ok, addr} = Utils.Network.get_local_ip()
      addr_str = :inet.ntoa(addr)
      full_name = name <> "@" <> to_string(addr_str)
      IO.puts("New node name: " <> full_name)

      Node.start(String.to_atom(full_name), :longnames)
      Node.set_cookie(:choc)

      String.to_atom(full_name)
    else
      IO.puts("Node already named: " <> to_string(Node.self()))
      Node.set_cookie(:choc)
      # String.split(to_string(Node.self()), "@") |> Enum.at(0)
      Node.self()
    end
  end

  defp dev_try_create_socket(port, max_port) do
    case :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}]) do
      {:ok, socket} ->
        {:ok, socket, port}

      {:error, :eaddrinuse} ->
        if port < max_port do
          dev_try_create_socket(port + 1, max_port)
        else
          {:error, :port_out_of_range}
        end
    end
  end

  def dev_network_loss(timeout) do
    IO.puts("simulating network loss")
    dev_disconnect()
    Process.sleep(timeout)
    dev_reconnect()
  end

  def dev_disconnect() do
    # To simulate a network failure
    # do this so we can stop broadcasting master hb
    Node.stop()
    state = get_state()
    set_state(%{state | test_disconnected: true})
    # do this to avoid having no name
    # Node.start(state.name, :longnames)
  end

  def dev_reconnect() do
    GenServer.call(__MODULE__, :dev_reconnect)
  end
end
