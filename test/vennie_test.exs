defmodule VennieTest do
  use ExUnit.Case
  doctest Vennie

  test "greets the world" do
    assert Vennie.hello() == :world
  end
end
