defmodule Ballot.CountingTest do
  use ExUnit.Case
  alias Ballot.RankedVote
  alias Ballot.Counting
  doctest Ballot.Counting

  describe "instant_runoff/2" do
    test "selects a winner by first choice" do
      assert "1" == Counting.instant_runoff([
        RankedVote.new(["1"]),
        RankedVote.new(["1"]),
        RankedVote.new(["2"])
      ])
    end

    test "selects a winner by second choice" do
      assert "3" == Counting.instant_runoff([
        RankedVote.new(["1", "3"]),
        RankedVote.new(["2", "3"]),
        RankedVote.new(["3"]),
        RankedVote.new(["3"])
      ])
    end

    test "selects a winner by second choice with configurable win percentage" do
      assert "6" == Counting.instant_runoff([
        RankedVote.new(["1", "6"]),
        RankedVote.new(["1", "6"]),
        RankedVote.new(["1", "6"]),
        RankedVote.new(["2", "6"]),
        RankedVote.new(["3", "6"]),
        RankedVote.new(["4", "6"]),
        RankedVote.new(["5", "6"]),
      ], win_percentage: 75)
    end
  end
end
