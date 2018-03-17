defmodule SparqlTest do
  use ExUnit.Case
  doctest Sparql

  test "greets the world" do
    assert Sparql.hello() == :world
  end
end
