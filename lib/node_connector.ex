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

  defmodule NodeConnector.State do
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
              test_disconnected: false
  end

  alias NodeConnector.State

  def start_link([]) do
    start_link([33333, "Elevator"])
  end

  def start_link([start_port, name]) do
    GenServer.start_link(__MODULE__, [start_port, name], name: __MODULE__)
  end

  ## client ------------------------------------------

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

  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  ## server ------------------------------------------

  def init([start_port, name]) do
    # dev
    # port = start_port
    # {:ok, socket} = :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}])
    {:ok, socket, port} = try_create_socket(start_port, start_port + @port_range)
    name = register_node(name)

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

  defp start_watchdog() do
    Process.send_after(self(), :timed_out, @timeout_time)
  end

  defp restart_watchdog(timer) do
    if timer != nil do
      Process.cancel_timer(timer)
    end

    Process.send_after(self(), :timed_out, @timeout_time)
  end

  # dev
  defp register_node(name) do
    if Node.self() == :nonode@nohost do
      {:ok, addr} = Network.Util.get_local_ip()
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

  # dev
  defp try_create_socket(port, max_port) do
    case :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}]) do
      {:ok, socket} ->
        {:ok, socket, port}

      {:error, :eaddrinuse} ->
        if port < max_port do
          # IO.puts("trying port #{port}")
          try_create_socket(port + 1, max_port)
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
    Node.start(state.name, :longnames)
  end

  def dev_reconnect() do
    GenServer.call(__MODULE__, :dev_reconnect)
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
    Node.set_cookie(:choc)

    state = %State{state | test_disconnected: false}

    if state.role == :master do
      send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
    end

    {:reply, :ok, state}
  end

  # info ------------------------------------------

  def handle_info(:timed_out, state) do
    IO.puts("Master timed out, upgrading self to master")

    # do something useful here...
    # like starting a dynamic supervisor
    state = %State{state | role: :master, master: Node.self()}
    send(self(), {:loop_master, state.start_port, state.start_port + @port_range})
    {:noreply, state}
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
      # watchdog should be started from handle_info(:udp,...)
      {:noreply, state}
    end
  end

  def handle_info({:udp, _socket, _host, _port, packet}, state) do
    [full_name | [up_since | _]] = String.split(to_string(packet), "_")
    up_since = String.to_integer(up_since)

    if not state.test_disconnected do
      if state.role == :slave do
        master =
          case state.master do
            nil ->
              IO.puts("Found master #{full_name}!")
              master = String.to_atom(full_name)
              Node.monitor(master, true)
              Node.connect(master)
              send({__MODULE__, master}, {:slave_connected, Node.self()})

              master

            _ ->
              state.master
          end

        {:noreply, %State{state | watchdog: restart_watchdog(state.watchdog), master: master}}
      else
        # handles case when there are multiple masters
        if up_since < state.up_since do
          # downgrade to slave
          IO.puts("Downgrading to slave")
          IO.puts("#{full_name} is the master")

          # need to ping master
          master = String.to_atom(full_name)
          Node.monitor(master, true)
          Node.connect(master)
          send({__MODULE__, master}, {:slave_connected, Node.self()})
          # :pong = Node.ping(mastr)

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

  def handle_info({:slave_connected, node_name}, state) do
    IO.puts("Slave #{node_name} connected!")

    # do something useful here...
    Node.monitor(node_name, true)
    [host_name | host_adr_str] = String.split(to_string(node_name), "@")
    {:noreply, %State{state | slaves: Map.put(state.slaves, host_name, host_adr_str)}}
  end

  def handle_info({:nodedown, node}, state) do
    IO.puts("Lost connection to node #{node}!")

    # do something useful here...

    name = node |> to_string() |> String.split("@") |> Enum.at(0)

    # delete master if master disconnected
    master = if node == state.master, do: nil, else: state.master

    {:noreply, %{state | master: master, slaves: Map.delete(state.slaves, name)}}
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
end
