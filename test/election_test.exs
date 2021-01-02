defmodule Ballot.ElectionTest do
  use ExUnit.Case
  doctest Ballot.Election

  test "raises when vote types are mixed" do
    election =
      Ballot.Election.new(["A"])
      |> Ballot.Election.vote(Ballot.PluralityVote.new("A"))

    assert_raise RuntimeError, fn ->
      Ballot.Election.vote(election, Ballot.ApprovalVote.new(["A"]))
    end
  end
end
