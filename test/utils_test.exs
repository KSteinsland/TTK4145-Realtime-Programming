defmodule UtilsNetworkTest do
  use ExUnit.Case
  doctest Utils.Network

  test "finds local ip" do
    {:ok, local_ip} = Utils.Network.get_local_ip()

    assert :inet.getif()
           |> elem(1)
           |> Enum.map(fn x -> elem(x, 0) end)
           |> Enum.find(&match?(^local_ip, &1)) ==
             local_ip
  end
end
