# Not a 

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

#     #:inet.gethostname()
#     #:inet.ntoa(address)
#     #:inet.parse_address()
