defmodule Ballot.IDTest do
  use ExUnit.Case
  doctest Ballot.ID

  test "human_readable generates four groups of four characters" do
    assert Ballot.ID.human_readable() =~ ~r/[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{4}/
  end
end
