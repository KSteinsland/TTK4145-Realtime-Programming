defmodule NodeConnector do
  @moduledoc """
  Ensures that we always have a master and connects the nodes.
  """
  use GenServer

  @broadcast_ip {255, 255, 255, 255}

  # need port_range to run multiple nodes on a computer
  @port_range Application.compile_env!(:elevator_project, :local_nodes)
  @sleep_time trunc(Application.compile_env!(:elevator_project, :broadcast_ms) / @port_range)
  @timeout_time Application.compile_env!(:elevator_project, :master_timeout_ms)

  defmodule State do
    defstruct socket: nil,
              port: nil,
              # dev
              start_port: nil,
              role: :slave,
              up_since: nil,
              watchdog: nil,
              master: {nil, 0},
              slaves: %{}
  end

  ## client ------------------------------------------

  def start_link([]) do
    start_link([33333, "node0"])
  end

  def start_link([start_port, name]) do
    GenServer.start_link(__MODULE__, [start_port, name], name: __MODULE__)
  end

  ## server ------------------------------------------

  def init([start_port, name]) do
    # dev
    # port = start_port
    # {:ok, socket} = :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}])
    {:ok, socket, port} = dev_try_create_socket(start_port, start_port + @port_range)

    if node() == :nonode@nohost do
      # Start a distributed node
      System.cmd("epmd", ["-daemon"])

      {:ok, addr} = NodeConnector.Network.get_local_ip()
      addr_str = :inet.ntoa(addr)
      full_name = name <> "@" <> to_string(addr_str)
      IO.puts("New node name: " <> full_name)

      Node.start(String.to_atom(full_name), :longnames)
      Node.set_cookie(:choc)
    else
      IO.puts("Node already named: " <> to_string(node()))
      Node.set_cookie(:choc)
    end

    {:ok,
     %State{
       socket: socket,
       port: port,
       start_port: start_port,
       up_since: System.os_time(:millisecond),
       watchdog: restart_watchdog(nil)
     }}
  end

  # cast ------------------------------------------

  def handle_cast({:slaves, slaves}, state) do
    # Notify a slave about the other slaves
    {:noreply, %State{state | slaves: slaves}}
  end

  # info ------------------------------------------

  def handle_info(:timed_out, state) do
    # Master timed out, find out who is the next master

    up_times = [state.up_since | state.slaves |> Map.values()]

    if state.role != :master and state.up_since <= Enum.min(up_times) do
      # We are next in line, as we have have the longest up time
      IO.puts("Master timed out, upgrading self to master")

      {master, _} = state.master

      if master != nil do
        Node.disconnect(master)
        StateServer.node_active(master, false)
      end

      # Start master only processes
      MasterStarter.upgrade_to_master()

      state = %State{
        state
        | watchdog: stop_watchdog(state.watchdog),
          role: :master,
          master: {node(), state.up_since},
          # unsure about this one
          slaves: %{}
      }

      send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
      {:noreply, state}
    else
      # Another slave should become master
      IO.puts("Waiting for another master")

      # Remove new master candidate from slave list
      new_master_candidate =
        state.slaves |> Enum.find(fn {_key, val} -> val == Enum.min(up_times) end) |> elem(0)

      new_slaves = state.slaves |> Map.delete(new_master_candidate)

      # If master candidate doesn't start, watchdog will time out again
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
    # Send udp broadcast, lets slaves find us, and know that we are alive

    if state.role == :master do
      :gen_udp.send(state.socket, @broadcast_ip, start_port, "#{node()}_#{state.up_since}")

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
    # Received a udp message from a master

    [full_name | [up_since | _]] = String.split(to_string(packet), "_")
    up_since = String.to_integer(up_since)
    latest_master = String.to_atom(full_name)

    if state.role == :slave do
      {current_master, current_up_since} = state.master

      Node.connect(latest_master)

      if current_master == nil or up_since < current_up_since do
        # Found a master, or a new master
        IO.puts("Found master #{full_name}!")

        send({__MODULE__, latest_master}, {:slave_connected, node(), state.up_since})

        {:noreply,
         %State{
           state
           | watchdog: restart_watchdog(state.watchdog),
             master: {latest_master, up_since}
         }}
      else
        # Do nothing
        {:noreply, %State{state | watchdog: restart_watchdog(state.watchdog)}}
      end
    else
      # We are master, both so is the message sender!
      if up_since < state.up_since do
        # Downgrade to slave
        IO.puts("Downgrading to slave")
        IO.puts("#{full_name} is the master")

        MasterStarter.downgrade_to_slave()

        Node.connect(latest_master)
        send({__MODULE__, latest_master}, {:slave_connected, node(), state.up_since})

        {:noreply,
         %State{
           state
           | role: :slave,
             slaves: %{},
             watchdog: restart_watchdog(state.watchdog),
             master: {latest_master, up_since}
         }}
      else
        # Do nothing,
        # We are the first master and the other node should downgrade
        {:noreply, state}
      end
    end
  end

  def handle_info({:slave_connected, node_name, up_since}, state) do
    IO.puts("Slave #{node_name} connected!")

    StateSynchronizer.update_node(node_name)
    StateServer.node_active(node_name, true)

    Node.monitor(node_name, true)
    new_slaves = Map.put(state.slaves, node_name, up_since)
    nodes = Node.list()
    GenServer.abcast(nodes, __MODULE__, {:slaves, new_slaves})

    {:noreply, %State{state | slaves: new_slaves}}
  end

  def handle_info({:nodedown, node}, state) do
    if state.role == :master do
      IO.puts("Lost connection to node #{node}!")

      Node.disconnect(node)
      StateServer.node_active(node, false)

      {:noreply, %{state | slaves: Map.delete(state.slaves, node)}}
    else
      {:noreply, state}
    end
  end

  # Utils ------------------------------------------

  defp restart_watchdog(timer) do
    if timer != nil, do: Process.cancel_timer(timer)
    Process.send_after(self(), :timed_out, @timeout_time)
  end

  defp stop_watchdog(timer) do
    if timer != nil, do: Process.cancel_timer(timer)
    nil
  end

  # Dev ------------------------------------------

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

  defmodule Network do
    @broadcast_ip {255, 255, 255, 255}
    @port 33332

    def get_local_ip() do
      if Application.fetch_env!(:elevator_project, :env) == :test do
        # for ease of testing
        {:ok, {127, 0, 0, 1}}
      else
        {:ok, socket} = :gen_udp.open(@port, [{:broadcast, true}, {:reuseaddr, true}])
        key = "udp_getting_ip" |> String.to_charlist()
        :gen_udp.send(socket, @broadcast_ip, @port, key)

        receive do
          {:udp, _port, localip, @port, ^key} ->
            :gen_udp.close(socket)
            {:ok, localip}
        after
          1000 ->
            :gen_udp.close(socket)
            {:error, "could not retreive local ip"}
        end
      end
    end
  end
end
