defmodule BallotCounterTest do
  use ExUnit.Case, async: true
  doctest BallotCounter

  # Examples from https://plato.stanford.edu/entries/voting-methods/

  @ranked_choice_ballot_distribution %{
    ["A", "B", "C", "D"] => 7,
    ["B", "C", "D", "A"] => 5,
    ["D", "B", "C", "A"] => 4,
    ["C", "D", "A", "B"] => 3,
  }

  test "plurality_with_runoff" do
    ballots = generate_ballots(@ranked_choice_ballot_distribution)

    assert "A" == BallotCounter.plurality_with_runoff(ballots)
  end

  test "instant_runoff" do
    ballots = generate_ballots(@ranked_choice_ballot_distribution)

    assert "D" == BallotCounter.instant_runoff(ballots)
  end

  test "coombs" do
    ballots = generate_ballots(@ranked_choice_ballot_distribution)

    assert "B" == BallotCounter.coombs(ballots)
  end

  defp generate_ballots(ballot_counts) do
    Enum.flat_map(ballot_counts, fn {ballot, count} ->
      Stream.repeatedly(fn -> ballot end) |> Enum.take(count)
    end)
  end
end
