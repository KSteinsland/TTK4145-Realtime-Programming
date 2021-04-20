defmodule FileBackup do
  @moduledoc """

  """

  def write(data, filename) do
    {:ok, file} = File.open(filename, [:write])
    binary = :erlang.term_to_binary(data)
    IO.binwrite(file, binary)
    File.close(file)
  end

  def read(filename) do
    case File.read(filename) do
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        {:ok, data}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
