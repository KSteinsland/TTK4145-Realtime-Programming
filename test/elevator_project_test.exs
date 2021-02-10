defmodule ELEVATOR_PROJECTTest do
  use ExUnit.Case
  doctest ELEVATOR_PROJECT

  test "greets the world" do
    assert ELEVATOR_PROJECT.hello() == :world
  end
end
