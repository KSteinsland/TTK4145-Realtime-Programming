defmodule NetworkTest do
  use ExUnit.Case
  doctest Network

  test "finds local ip" do
    {:ok, local_ip} = Network.get_local_ip()

    assert :inet.getif()
           |> elem(1)
           |> Enum.map(fn x -> elem(x, 0) end)
           |> Enum.find(&match?(^local_ip, &1)) ==
             local_ip
  end
end

defmodule UDPBroadcastTest do
  # , async: true
  use ExUnit.Case
  doctest UDPBroadcast

  # import ExUnit.CaptureIO

  defp setup_slaves(addr, limit) do
    Enum.each(1..limit, fn index ->
      IO.puts("starting slave #{index}")
      :slave.start_link(addr, 'slave_#{index}')
    end)

    [node() | Node.list()]
  end

  setup do
    System.cmd("epmd", ["-daemon"])
    port = 33330
    {:ok, pid} = UDPBroadcast.start_link([port, "test_udp"])
    %{pid: pid, port: port}
  end

  test "starts the server", %{pid: pid} do
    assert UDPBroadcast.get_all(pid) == %{}
  end

  test "handles invalid commands correctly", %{pid: pid} do
    # This test needs to be improved
    msg = {:test, 3242}
    send(pid, msg)
    assert Process.alive?(pid)
  end

  # test "receives incoming messages", %{pid: pid, port: port} do
  #   # This test needs to be improved

  #   {:ok, ip} = Network.get_local_ip()
  #   nodes = setup_slaves(String.to_atom(List.to_string(:inet.ntoa(ip))), 2)

  #   IO.inspect(nodes)

  #   #:gen_udp.send()
  #   #send(pid, {:udp, "dummy_socket", {1,1,1,1}, port, "testhost@1.1.1.1"})

  #   assert UDPBroadcast.get_all(pid) == %{testhost: {1,1,1,1}}
  # end

  # test "server is down", %{pid: pid} do
  #   send pid, :shutdown
  #   assert !Process.alive?(pid)
  # end
end
