defmodule NetworkTest do
  use ExUnit.Case
  doctest Network

  test "finds local ip" do
    {:ok, local_ip} = Network.Util.get_local_ip()

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

    case NodeConnector.start_link([port, "test_udp"]) do
      {:ok, _pid} ->
        :ok

      {:error, _err_msg} ->
        :ok
    end
  end

  test "starts the server" do
    assert NodeConnector.get_all() == %{}
  end

  # test "check for other nodes", %{pid: _pid} do
  #   Process.sleep(2500)
  #   #IO.inspect NodeConnector.get_all()
  #   IO.inspect(Node.list)
  #   assert True
  # end
end
