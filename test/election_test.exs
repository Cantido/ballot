defmodule Ballot.ElectionTest do
  use ExUnit.Case
  doctest Ballot.Election

  test "adding a vote" do
    election =
      Ballot.Election.new(["A"])
      |> Ballot.Election.vote(Ballot.PluralityVote.new("A"))
      |> Ballot.Election.vote(Ballot.PluralityVote.new("A"))
      |> Ballot.Election.vote(Ballot.PluralityVote.new("B"))

    assert ["A"] = Ballot.Counting.plurality(election.votes)
  end

  test "raises when vote types are mixed" do
    election =
      Ballot.Election.new(["A"])
      |> Ballot.Election.vote(Ballot.PluralityVote.new("A"))

    assert_raise RuntimeError, fn ->
      Ballot.Election.vote(election, Ballot.ApprovalVote.new(["A"]))
    end
  end
end
