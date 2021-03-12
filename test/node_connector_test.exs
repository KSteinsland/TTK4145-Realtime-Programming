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

defmodule NodeConnectorTest do
  use ExUnit.Case, async: false
  doctest NodeConnector

  setup do
    System.cmd("epmd", ["-daemon"])
    port = 33333
    {:ok, pid} = NodeConnector.start_link([port, "test_udp"])
    %{pid: pid, port: port}
  end

  test "starts the server", %{pid: _pid} do
    assert NodeConnector.get_all() == %{}
  end

  # test "check for other nodes", %{pid: _pid} do
  #   Process.sleep(2500)
  #   #IO.inspect NodeConnector.get_all()
  #   IO.inspect(Node.list)
  #   assert True
  # end

  test "handles invalid commands correctly", %{pid: pid} do
    # This test needs to be improved
    msg = {:test, 3242}
    send(pid, msg)
    assert Process.alive?(pid)
  end
end
