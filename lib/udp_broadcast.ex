defmodule UDPBroadcast do

  def start_server do
      {:ok, socket} = :gen_udp.open(33333, [{:broadcast, true}])
      Task.start_link(fn -> loop_send(socket) end)
      spawn loop(socket, %{})
  end

  defp loop_send(socket) do
      Process.sleep(3000)
      :gen_udp.send(socket, {255,255,255,255}, 33333, "Hello!")
      loop_send(socket)
  end

  defp loop(socket, map) do
      #:inet.gethostname()
      #:inet.ntoa(address)
      #:inet.parse_address()

      receive do
      {:udp, socket, host, port, packet} ->
          #IO.puts(packet)
          IO.inspect packet
          IO.inspect host
          IO.inspect map

          host_adr_str = :inet.ntoa(host)

          if Map.get(map, host_adr_str) == nil do
              :gen_udp.send(socket, host, 33333, "Hello There!")
              loop(socket, Map.put(map, host_adr_str, 0))

          end
          val = Map.get(map, host_adr_str)
          loop(socket, Map.put(map, host_adr_str, val+1))

      end
  end

end
