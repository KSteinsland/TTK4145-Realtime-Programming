defmodule UDPBroadcast do
  use GenServer

  @broadcast_ip {255, 255, 255, 255}
  @sleep_time 3000

  def start_link([]) do
    start_link([33333, "Elevator"])
  end

  def start_link([port, name]) do
    GenServer.start_link(__MODULE__, [port, name], name: __MODULE__)
  end

  ## client side

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  ## server

  def init([port, name]) do
    {:ok, socket} = :gen_udp.open(port, [{:broadcast, true}, {:reuseaddr, true}])

    # IO.inspect(Node.self())

    if Node.self() == :nonode@nohost do
      {:ok, addr} = Network.get_local_ip()
      addr_str = :inet.ntoa(addr)
      full_name = name <> "@" <> to_string(addr_str)
      IO.puts("New node name: " <> full_name)

      Node.start(String.to_atom(full_name), :longnames)
      Node.set_cookie(:choc)

      task = Task.start_link(fn -> loop_send(socket, port) end)

      {:ok, %{socket: socket, port: port, name: name, task: task, nodes: %{}}}
    else
      [name | _] = String.split(to_string(Node.self()), "@")

      task = Task.start_link(fn -> loop_send(socket, port) end)

      {:ok, %{socket: socket, port: port, name: name, task: task, nodes: %{}}}
    end
  end

  defp loop_send(socket, port) do
    Process.sleep(@sleep_time)
    :gen_udp.send(socket, @broadcast_ip, port, "#{Node.self()}")
    loop_send(socket, port)
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state.nodes, state}
  end

  def handle_info(:shutdown, state) do
    :gen_udp.close(state.socket)
    Task.shutdown(state.task)
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
  @port 33334

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
