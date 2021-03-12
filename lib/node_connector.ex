defmodule NodeConnector do
  use GenServer

  @broadcast_ip {255, 255, 255, 255}
  @sleep_time 1000
  @port_range Application.fetch_env!(:elevator_project, :port_range)

  def start_link([]) do
    start_link([33333, "Elevator"])
  end

  def start_link([start_port, name]) do
    GenServer.start_link(__MODULE__, [start_port, name], name: __MODULE__)
  end

  ## client side

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  ## server

  def init([start_port, name]) do
    {:ok, socket, port} = try_create_socket(start_port, start_port + @port_range)
    name = register_node(name)
    send(self(), {:loop_send, start_port, start_port + @port_range})
    {:ok, %{socket: socket, port: port, name: name, nodes: %{}}}
  end

  defp register_node(name) do
    if Node.self() == :nonode@nohost do
      {:ok, addr} = Network.get_local_ip()
      addr_str = :inet.ntoa(addr)
      full_name = name <> "@" <> to_string(addr_str)
      IO.puts("New node name: " <> full_name)

      Node.start(String.to_atom(full_name), :longnames)
      Node.set_cookie(:choc)

      name
    else
      IO.puts("Node already named: " <> to_string(Node.self()))
      String.split(to_string(Node.self()), "@") |> Enum.at(0)
    end
  end

  defp try_create_socket(port, max_port) do
    case :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}]) do
      {:ok, socket} ->
        {:ok, socket, port}

      {:error, :eaddrinuse} ->
        if port < max_port do
          IO.puts("trying port #{port}")
          try_create_socket(port + 1, max_port)
        else
          {:error, :port_out_of_range}
        end
    end
  end

  def handle_call(:get_all, _from, state) do
    IO.puts("getting all nodes")
    {:reply, state.nodes, state}
  end

  def handle_info({:loop_send, start_port, end_port}, state) do
    :gen_udp.send(state.socket, @broadcast_ip, start_port, "#{Node.self()}")
    # IO.puts("sending udp")

    new_port = fn start_port, end_port ->
      if start_port == end_port do
        start_port - @port_range
      else
        start_port
      end
    end

    Process.send_after(
      self(),
      {:loop_send, new_port.(start_port, end_port), end_port},
      @sleep_time
    )

    {:noreply, state}
  end

  def handle_info(:shutdown, state) do
    :gen_udp.close(state.socket)
    Process.exit(self(), :kill)
    {:noreply, state}
  end

  def handle_info({:udp, _socket, host, _port, packet}, state) do
    # should probably pin these

    host_adr_str = :inet.ntoa(host)
    [host_name | _] = String.split(to_string(packet), "@")
    full_name = host_name <> "@" <> to_string(host_adr_str)

    if Map.get(state.nodes, host_name) == nil && host_name != state.name do
      IO.puts("New node!")
      # :gen_udp.send(socket, host, port, "Hello There!")
      Node.ping(String.to_atom(full_name))
      IO.inspect(Node.list())
      {:noreply, %{state | nodes: Map.put(state.nodes, host_name, host_adr_str)}}
    else
      {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    IO.inspect("Invalid Message: ")
    IO.inspect(msg)
    {:noreply, state}
  end
end

defmodule Network do
  @broadcast_ip {255, 255, 255, 255}
  @port 33332

  def get_local_ip() do
    {:ok, socket} = :gen_udp.open(@port, [{:broadcast, true}, {:reuseaddr, true}])
    key = Random.gen_rand_str(5) |> String.to_charlist()
    # packet gets converted to charlist!
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