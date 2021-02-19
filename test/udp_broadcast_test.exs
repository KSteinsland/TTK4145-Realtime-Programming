defmodule NetworkTest do
  use ExUnit.Case
  doctest Network

  test "finds local ip" do
    {:ok, local_ip} = Network.get_local_ip()
    assert :inet.getif
    |> elem(1)
    |> Enum.map(fn x -> elem(x,0) end)
    |> Enum.find(&match?(^local_ip, &1))
    == local_ip
  end
end
