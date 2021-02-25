defmodule FindNodes do
  @broadcast_ip {255,255,255,255}
  @sleep_time 3000

  def create_socket(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, broadcast: true])
    socket
  end

  def broadcast_self(socket, receiver_port) do 
      Process.sleep(@sleep_time)
      
      me = to_string(Node.self)
      :gen_udp.send(socket, @broadcast_ip, receiver_port, me)

      broadcast_self(socket, receiver_port)
  end

  
  def listen_for_nodes(socket) do
    Process.sleep(@sleep_time)

    {:ok, {_ip, _port, node}} = :gen_udp.recv(socket, 0)
    Node.ping(String.to_atom(node))

    listen_for_nodes(socket)
  end


  #Test functions
  def test_broadcast do
    s = create_socket(9090)
    Task.start(fn ->  broadcast_self(s, 9091) end)
   
  end

  def test_listen do
    s = create_socket(9091)
    Task.start(fn -> listen_for_nodes(s) end)
  end
end

