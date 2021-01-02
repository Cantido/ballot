defmodule Ballot.IDTest do
  use ExUnit.Case
  doctest Ballot.ID

  test "generates four groups of four characters" do
    assert Ballot.ID.generate() =~ ~r/[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{4}/
  end
end
