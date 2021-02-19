defmodule UDPBroadcast do
  use GenServer

  @broadcast_ip {255,255,255,255}
  @sleep_time 3000

  ## client side

  def start(port \\ 33333) do
    GenServer.start_link(__MODULE__, port)
  end

  def get_all(server_pid) do
    GenServer.call(server_pid, :get_all)
  end

  ## server

  def init(port) do

    {:ok, socket} = :gen_udp.open(port, [{:broadcast, true}])
    IO.inspect(Node.self())

    if Node.self() == :nonode@nohost do
      name = Random.gen_rand_str(5)

      #{:ok, [host_info | _]} = :inet.getif()
      #[addr | _] = Tuple.to_list(host_info)
      {:ok, addr} = Network.get_local_ip()
      addr_str = :inet.ntoa(addr)

      full_name = name <> "@" <> to_string(addr_str)

      Node.start(String.to_atom(full_name), :longnames)

      Node.set_cookie(:choc)

      Task.start_link(fn -> loop_send(socket, port) end)

      {:ok, {socket, port, name, %{}}}
    else
      [name | _] = String.split(to_string(Node.self()), "@")

      Task.start_link(fn -> loop_send(socket, port) end)

      {:ok, {socket, port, name, %{}}}
    end
  end


  defp loop_send(socket, port) do
      Process.sleep(@sleep_time)
      :gen_udp.send(socket, @broadcast_ip, port, "#{Node.self}")
      loop_send(socket, port)

  end

  def handle_call(:get_all, _from, state) do
    {_, _, _, nodes} = state
    {:reply, nodes, state}
  end

  def handle_info(:shutdown, state) do
    {socket, _port, _name, _nodes} = state
    :gen_udp.close(socket)
    Process.exit(self(), :kill)
    {:noreply, state}
  end

  def handle_info({:udp, socket, host, port, packet}, state) do
    IO.inspect packet
    IO.inspect host
    IO.inspect state

    #should probably pin these
    {_socket, _port, name, nodes} = state

    host_adr_str = :inet.ntoa(host)

    [host_name | _] = String.split(to_string(packet), "@")
    full_name = host_name <> "@" <> to_string(host_adr_str)

    IO.inspect(nodes)
    Process.sleep(1000)

    if Map.get(nodes, host_name) == nil && host_name != name do
      IO.puts("New node!")
      #:gen_udp.send(socket, host, 33333, "Hello There!")
      Node.ping(String.to_atom(full_name))
      {:noreply, {socket, port, name, Map.put(nodes, host_name, host_adr_str)}}
    else
      {:noreply, {socket, port, name, nodes}}
    end
  end

  def handle_info(msg, state) do
    IO.inspect("Invalid Message: #{msg}")
    {:noreply, state}
  end
end


defmodule Network do
  @broadcast_ip {255,255,255,255}
  @port 33334

  def get_local_ip() do
    {:ok, socket} = :gen_udp.open(@port, [{:broadcast, true}, {:reuseaddr, true}])
    key = Random.gen_rand_str(5) |> String.to_charlist()
    :gen_udp.send(socket, @broadcast_ip, @port, key) # packet gets converted to charlist!

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

defmodule Random do

  def gen_rand_str(length) do
    do_randomizer(length, "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("", trim: true))
  end

  defp do_randomizer(length, lists) do
    1..length
    |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
    |> Enum.join("")
  end
end

  #     #:inet.gethostname()
  #     #:inet.ntoa(address)
  #     #:inet.parse_address()
