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

    if to_string(Node.self()) == "nonode@nohost" do
      name = do_randomizer(5, "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("", trim: true))
      Node.start(String.to_atom(name))

      Task.start_link(fn -> loop_send(socket, port) end)

      {:ok, {socket, port, name, %{}}}
    else
      [name | _] = String.split(to_string(Node.self()), "@")

      Task.start_link(fn -> loop_send(socket, port) end)

      {:ok, {socket, port, name, %{}}}
    end

  end

  defp do_randomizer(length, lists) do
    1..length
    |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
    |> Enum.join("")
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

  def handle_info({:udp, socket, host, port, packet}, state) do
    IO.inspect packet
    IO.inspect host
    IO.inspect state

    {socket, port, name, nodes} = state

    host_adr_str = :inet.ntoa(host)


    [host_name | _] = String.split(to_string(packet), "@")
    full_name = host_name <> "@" <> to_string(host_adr_str)


    IO.inspect(nodes)
    Process.sleep(1000)

    unless host_name == name do
      if Map.get(nodes, host_name) == nil do
        IO.puts("New node!")
        #:gen_udp.send(socket, host, 33333, "Hello There!")
        Node.ping(String.to_atom(full_name))
        {:noreply, {socket, port, name, Map.put(nodes, host_name, host_adr_str)}}
      end
    end

    {:noreply, {socket, port, name, nodes}}

  end

  def handle_info(msg, state) do
    IO.inspect("Invalid Message: #{msg}")
    {:noreply, state}
  end
end


  #     #:inet.gethostname()
  #     #:inet.ntoa(address)
  #     #:inet.parse_address()
