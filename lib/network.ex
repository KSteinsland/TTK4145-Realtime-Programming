defmodule Network do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  ## client side

  # DEBUG
  def get_counter() do
    GenServer.call(__MODULE__, :get_counter)
  end

  def send_2_node(dest, data, nodes \\ []) do
    GenServer.call(__MODULE__, {:send_2_node, dest, data, nodes})
  end

  ## server

  def init([]) do
    {:ok, %{counter: 0}}
  end

  def handle_call(:get_counter, _from, state) do
    IO.puts("getting counter")
    {:reply, state.counter, state}
  end

  def handle_call({:send_2_node, dest, data, nodes}, _from, state) do
    {:reply, :ok, %{state | counter: state.counter + 1},
     {:continue, {:send_cont, dest, data, nodes}}}
  end

  def handle_continue({:send_cont, dest, data, nodes}, state) do
    for node <- send_to(nodes) do
      IO.puts("sending to #{node}!")
      send({Network, node}, {:new_msg, dest, data, state.counter})
    end

    {:noreply, state}
  end

  def handle_info({:new_msg, dest, data, counter}, state) when counter > state.counter do
    IO.puts("rec msg!")
    IO.inspect(data)
    send(dest, data)
    {:noreply, %{state | counter: counter}}
  end

  def handle_info({:new_msg, _dest, _data, _counter}, state) do
    IO.puts("Outdated msg!")
    # should do something here to send new state to outdated server
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.inspect("Network invalid Message: ")
    IO.inspect(msg)
    {:noreply, state}
  end

  defp send_to(nodes) do
    if Enum.empty?(nodes) do
      Node.list()
    else
      nodes
    end
  end
end

defmodule Network.Util do
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
