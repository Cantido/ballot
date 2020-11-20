defmodule Ballot.Counting do
  @moduledoc """
  Implements vote counting strategies.
  """

  @doc """
  Counts first place votes, and if the winner has more than 50% of the vote, they win.
  If not, the candidate with the least number of first-choice votes is dropped,
  and the votes are tallied again,
  this time taking the second choice of any votes that had the loser first.
  Ties for last place result in multiple candidates being removed in one round.

  ## Examples

  In the simplest case, the candidate with more than fifty percent of the
  first-choice votes wins.

      iex> votes = [
      ...>   Ballot.RankedVote.new(["1"]),
      ...>   Ballot.RankedVote.new(["1"]),
      ...>   Ballot.RankedVote.new(["2"])
      ...> ]
      iex> Ballot.Counting.instant_runoff(votes)
      "1"

    If no candidate got at least fifty percent of the vote,
    the candidate with the smallest amount of votes is eliminated.
    This means you look to the second choice on any votes that have that
    candidate as first choice.

    In this example, no candidates win on the first pass,
    as "3" does not have *greater than fifty percent* of the vote.
    Candidates "1" and "2" will lose the first round.
    Votes with "1" and "2" first will then fall back to their next choice,
    granting "3" the victory with four out of four votes.

    iex> votes = [
    ...>   Ballot.RankedVote.new(["1", "3"]),
    ...>   Ballot.RankedVote.new(["2", "3"]),
    ...>   Ballot.RankedVote.new(["3"]),
    ...>   Ballot.RankedVote.new(["3"])
    ...> ]
    iex> Ballot.Counting.instant_runoff(votes)
    "3"

    You can also pass in a required win percentage greater than 50.0,
    and less than or equal to 100.
    In this case, candidates "2," "3," and "4" lose the first round,
    and their votes are now for "6".
    In the second round, "1" then loses, and their votes count for "6".
    Candidate "6" then wins.

    iex> votes = [
    ...>   Ballot.RankedVote.new(["1", "6"]),
    ...>   Ballot.RankedVote.new(["1", "6"]),
    ...>   Ballot.RankedVote.new(["1", "6"]),
    ...>   Ballot.RankedVote.new(["2", "6"]),
    ...>   Ballot.RankedVote.new(["3", "6"]),
    ...>   Ballot.RankedVote.new(["4", "6"]),
    ...>   Ballot.RankedVote.new(["5", "6"]),
    ...> ]
    iex> Ballot.Counting.instant_runoff(votes, required_percentage: 75.0)
    "6"
  """
  def instant_runoff(ranked_votes, opts \\ []) do
    do_instant_runoff(ranked_votes, [], opts)
  end

  defp do_instant_runoff(ranked_votes, losers, opts) do
    tallies =
      Enum.reduce(ranked_votes, %{}, fn vote, acc ->
        candidate_id =
          vote.choices
          |> Enum.drop_while(&(&1 in losers))
          |> Enum.at(0)

        if candidate_id do
          Map.update(acc, candidate_id, 1, &(&1 + 1))
        else
          acc
        end
      end)

    {{_worst_candidate, worst_votes}, {best_candidate, best_votes}} =
      Enum.min_max_by(tallies, fn {_candidate_id, tally} -> tally end)

    # Detect ties for last place
    worst_candidates =
      Enum.filter(tallies, fn {_id, tally} -> tally == worst_votes end)
      |> Enum.map(fn {id, _tally} -> id end)

    # choices_count isn't necessarily Enum.count(ranked_votes),
    # since a vote could have only losers in it.
    choice_count =
      Enum.reduce(tallies, 0, fn {_candidate_id, votes}, acc ->
        acc + votes
      end)

    best_percentage = best_votes / choice_count * 100
    win_percentage = Keyword.get(opts, :win_percentage, 50.0)

    if best_percentage > win_percentage do
      best_candidate
    else
      do_instant_runoff(ranked_votes, worst_candidates ++ losers, opts)
    end
  end
end
