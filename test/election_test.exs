defmodule Ballot.ElectionTest do
  use ExUnit.Case
  doctest Ballot.Election

  test "adding a vote" do
    election = Ballot.Election.new(["A", "B"])
    {:ok, election} = Ballot.Election.cast(election, Ballot.PluralityVote.new("A"))
    {:ok, election} = Ballot.Election.cast(election, Ballot.PluralityVote.new("A"))
    {:ok, election} = Ballot.Election.cast(election, Ballot.PluralityVote.new("B"))

    assert ["A"] = Ballot.Counting.plurality(election.votes)
  end

  test "raises when vote types are mixed" do
    election = Ballot.Election.new(["A"])
    {:ok, election} = Ballot.Election.cast(election, Ballot.PluralityVote.new("A"))

    assert {:error, :wrong_vote_type} == Ballot.Election.cast(election, Ballot.ApprovalVote.new(["A"]))
  end

  test "raises when a duplicate vote is added" do
    vote = Ballot.PluralityVote.new("A")

    election = Ballot.Election.new(["A"])
    {:ok, election} = Ballot.Election.cast(election, vote)

    assert {:error, :duplicate_vote} == Ballot.Election.cast(election, vote)
  end

  test "raises when a vote has candidates not in the election" do
    election = Ballot.Election.new(["A"])

    assert {:error, :candidate_not_in_election} == Ballot.Election.cast(election, Ballot.PluralityVote.new("B"))
  end
end
