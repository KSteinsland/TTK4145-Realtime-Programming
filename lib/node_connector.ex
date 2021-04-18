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
              master: {nil, 0},
              slaves: %{}
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

  # debug
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # TODO remove
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

    # Amount of seconds before timeout
    :net_kernel.set_net_ticktime(2, 2)

    {:ok,
     %State{
       socket: socket,
       port: port,
       start_port: start_port,
       name: name,
       up_since: System.os_time(:millisecond),
       watchdog: restart_watchdog(nil)
     }}
  end

  # calls ------------------------------------------

  # TODO remove
  def handle_call(:get_all_slaves, _from, state) do
    {:reply, state.slaves, state}
  end

  def handle_call(:get_self, _from, state) do
    {:reply, state.name, state}
  end

  # TODO remove
  def handle_call(:get_role, _from, state) do
    {:reply, state.role, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, _state) do
    {:reply, :ok, new_state}
  end

  def handle_info(:dev_reconnect, state) do
    Node.start(state.name, :longnames)
    Node.set_cookie(:choc)
    {:ok, socket} = :gen_udp.open(state.port, [{:broadcast, true}, {:reuseaddr, true}])

    {:noreply, %State{state | socket: socket}}
  end

  def handle_info(:dev_disconnect, state) do
    :gen_udp.close(state.socket)

    Enum.map(Node.list(), fn node ->
      Node.disconnect(node)
    end)

    Node.stop()

    # do this to avoid having no name
    Node.start(state.name, :longnames)

    {:noreply, state}
  end

  # info ------------------------------------------

  def handle_info(:timed_out, state) do
    up_times = [state.up_since | state.slaves |> Map.values()]

    if state.role != :master and state.up_since <= Enum.min(up_times) do
      IO.puts("Master timed out, upgrading self to master")

      MasterSupervisor.upgrade_to_master()

      state = %State{
        state
        | watchdog: stop_watchdog(state.watchdog),
          role: :master,
          master: {Node.self(), state.up_since},
          # unsure about this one
          slaves: %{}
      }

      send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
      {:noreply, state}
    else
      # waiting for another slave to become master
      IO.puts("waiting for another master")

      new_master_candidate =
        state.slaves |> Enum.find(fn {_key, val} -> val == Enum.min(up_times) end) |> elem(0)

      new_slaves = state.slaves |> Map.delete(new_master_candidate)

      state = %State{
        state
        | master: {nil, 0},
          slaves: new_slaves,
          watchdog: restart_watchdog(state.watchdog)
      }

      {:noreply, state}
    end
  end

  # dev
  # def handle_info(:loop_master, state) do
  def handle_info({:loop_master, start_port, end_port}, state) do
    if state.role == :master do
      :gen_udp.send(state.socket, @broadcast_ip, start_port, "#{Node.self()}_#{state.up_since}")

      # dev note, if dev_disconnect has been called, the disconnected node will not be able to send udp
      # as we close the socket

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
    # IO.inspect(latest_master)

    if state.role == :slave do
      {current_master, current_up_since} = state.master

      if current_master == nil or up_since < current_up_since do
        # unsure about this
        IO.puts("Found master #{full_name}!")

        Node.connect(latest_master)
        send({__MODULE__, latest_master}, {:slave_connected, Node.self(), state.up_since})

        {:noreply,
         %State{
           state
           | watchdog: restart_watchdog(state.watchdog),
             master: {latest_master, up_since}
         }}
      else
        {:noreply, %State{state | watchdog: restart_watchdog(state.watchdog)}}
      end
    else
      # handles case when there are multiple masters
      if up_since < state.up_since do
        # unsure about this!!
        # downgrade to slave
        IO.puts("Downgrading to slave")
        IO.puts("#{full_name} is the master")

        MasterSupervisor.downgrade_to_slave()

        Node.connect(latest_master)
        send({__MODULE__, latest_master}, {:slave_connected, Node.self(), state.up_since})

        {:noreply,
         %State{
           state
           | role: :slave,
             slaves: %{},
             watchdog: restart_watchdog(state.watchdog),
             master: {latest_master, up_since}
         }}
      else
        # do nothing, we are the "first" master and the other node should downgrade
        {:noreply, state}
      end
    end
  end

  def handle_info({:slave_connected, node_name, up_since}, state) do
    IO.puts("Slave #{node_name} connected!")

    StateDistribution.update_requests(node_name)
    StateDistribution.update_node(node_name)
    StateDistribution.node_active(node_name, true)

    Node.monitor(node_name, true)
    new_slaves = Map.put(state.slaves, node_name, up_since)
    nodes = Node.list()
    GenServer.abcast(nodes, __MODULE__, {:slaves, new_slaves})
    # send({__MODULE__, node_name}, {:slaves, new_slaves})
    {:noreply, %State{state | slaves: new_slaves}}
  end

  def handle_cast({:slaves, slaves}, state) do
    {:noreply, %State{state | slaves: slaves}}
  end

  def handle_info({:nodedown, node}, state) do
    if state.role == :master do
      IO.puts("Lost connection to node #{node}!")

      StateDistribution.node_active(node, false)

      {:noreply, %{state | slaves: Map.delete(state.slaves, node)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:nodeup, node}, state) do
    IO.puts("#{node} up!!")
    {:noreply, state}
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
    NodeConnector.dev_disconnect()
    NodeConnector.dev_reconnect(timeout)
  end

  def dev_disconnect() do
    send(__MODULE__, :dev_disconnect)
  end

  def dev_reconnect(timeout \\ 0) do
    Process.send_after(__MODULE__, :dev_reconnect, timeout)
  end
end
