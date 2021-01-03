defmodule Ballot.ElectionTest do
  use ExUnit.Case
  doctest Ballot.Election

  test "adding a vote" do
    election =
      Ballot.Election.new(["A", "B"])
      |> Ballot.Election.cast(Ballot.PluralityVote.new("A"))
      |> Ballot.Election.cast(Ballot.PluralityVote.new("A"))
      |> Ballot.Election.cast(Ballot.PluralityVote.new("B"))

    assert ["A"] = Ballot.Counting.plurality(election.votes)
  end

  test "raises when vote types are mixed" do
    election =
      Ballot.Election.new(["A"])
      |> Ballot.Election.cast(Ballot.PluralityVote.new("A"))

    assert_raise RuntimeError, fn ->
      Ballot.Election.cast(election, Ballot.ApprovalVote.new(["A"]))
    end
  end

  test "raises when a duplicate vote is added" do
    vote = Ballot.PluralityVote.new("A")

    election =
      Ballot.Election.new(["A"])
      |> Ballot.Election.cast(vote)

    assert_raise RuntimeError, fn ->
      Ballot.Election.cast(election, vote)
    end
  end

  test "raises when a vote has candidates not in the election" do
    election = Ballot.Election.new(["A"])

    assert_raise RuntimeError, fn ->
      Ballot.Election.cast(election, Ballot.PluralityVote.new("B"))
    end
  end
end
