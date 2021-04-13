defmodule Utils do
  defmodule Random do
    def gen_rand_str(length) do
      do_randomizer(length, "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("", trim: true))
    end

    defp do_randomizer(length, lists) do
      1..length
      |> Enum.reduce([], fn _, acc -> [Enum.random(lists) | acc] end)
      |> Enum.join("")
    end
  end

  defmodule Network do
    @broadcast_ip {255, 255, 255, 255}
    @port 33332

    def get_local_ip() do
      if Application.fetch_env!(:elevator_project, :env) == :test do
        # for ease of testing
        {:ok, {127, 0, 0, 1}}
      else
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
  end
end
