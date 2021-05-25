defmodule Ballot do
  @moduledoc """
  A vote-counting library.

  Candidates are usually represented by a string, which could be something like your candidate's ID number, or name.
  You can use anything that can be compared by value.

  In the simplest voting system, first-past-the-post AKA plurality voting, all you need is an enumerable of those candidate values.

      iex> Ballot.plurality(["A", "A", "A", "B", "B"])
      "A"

  More complex votes are represented by plain Elixir data structures.
  For example, votes for any ranked-choice voting system, like Instant Runoff,
  are just lists with values at the front of the list being a higher rank than values at the end of the list.

      iex> votes = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...>   ["C"],
      ...>   ["C"]
      ...> ]
      iex> Ballot.instant_runoff(votes)
      "C"
      iex> Ballot.dowdall(votes)
      "C"
      iex> Ballot.borda(votes) |> Enum.sort()
      ["B", "C"]

  Approval voting is similar, but votes are lists of all the candidates a voter approves of, so order doesn't matter.

      iex> votes = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> Ballot.approval(votes)
      "B"

  In score voting, each vote is a map of candidates to a numeric score.

      iex> votes = [
      ...>   %{"A" => 5, "B" => 4, "C" => 1},
      ...>   %{"A" => 1, "B" => 4, "C" => 1},
      ...> ]
      iex> Ballot.score(votes)
      "B"

  In case of ties, these functions return a list of all the winners.

      iex> Ballot.plurality(["A", "A", "B", "B"]) |> Enum.sort()
      ["A", "B"]

  ## Performance

  All counting functions traverse the input enumerables as few times as possible.
  They are all *O(n)* (or *O(n×m)*, where *m* is the length of a single ranked or score vote), with most traversing the input enum just once.

  Also, this library heavily uses `Stream`s.
  Therefore, you should be able to use `Stream`s as inputs to get the highest counting speeds possible.
  """

  @doc """
  Grants the win to the candidate with the most votes.

  ## Examples

      iex> Ballot.plurality(["A", "A", "A", "B", "B"])
      "A"

  Returns a list in case of ties.

      iex> Ballot.plurality(["A", "A", "B", "B"]) |> Enum.sort()
      ["A", "B"]
  """
  @spec plurality(Enumerable.t()) :: any()
  def plurality(votes) do
    Stream.map(votes, &{&1, 1})
    |> all_max_scores()
    |> winner_or_tie()
  end

  @doc """
  The quintessential ranked voting strategy.

  Counts first place votes, and if the winner has more than 50% of the vote, they win.
  If not, the candidate with the least number of first-choice votes is dropped,
  and the votes are tallied again,
  this time taking the second choice of any votes that had the loser first.
  Ties for last place result in multiple candidates being removed in one round.

  ## Examples

  In the simplest case, the candidate with more than fifty percent of the
  first-choice votes wins.

    iex> votes = [
    ...>   ["A"],
    ...>   ["A"],
    ...>   ["B"]
    ...> ]
    iex> Ballot.instant_runoff(votes)
    "A"

  If no candidate got at least fifty percent of the vote,
  the candidate with the smallest amount of votes is eliminated.
  This means you look to the second choice on any votes that have that
  candidate as first choice.

  In this example, no candidates win on the first pass,
  as `"C"` does not have *greater than fifty percent* of the vote.
  Candidates `"A"` and `"B"` will lose the first round.
  Votes with `"A"` and `"B"` first will then fall back to their next choice,
  granting `"C"` the victory with four out of four votes.

      iex> votes = [
      ...>   ["A", "C"],
      ...>   ["B", "C"],
      ...>   ["C"],
      ...>   ["C"]
      ...> ]
      iex> Ballot.instant_runoff(votes)
      "C"

  You can also pass in a required win percentage greater than 50.0,
  and less than or equal to 100.
  In this case, candidates `"B"`, `"C"`, and `"D"` lose the first round,
  and their votes are now for `"F"`.
  In the second round, `"A"` then loses, and their votes count for `"F"`.
  Candidate `"F"` then wins.

      iex> votes = [
      ...>   ["A", "F"],
      ...>   ["A", "F"],
      ...>   ["A", "F"],
      ...>   ["B", "F"],
      ...>   ["C", "F"],
      ...>   ["D", "F"],
      ...>   ["E", "F"],
      ...> ]
      iex> Ballot.instant_runoff(votes, required_percentage: 75.0)
      "F"

  It is impossible for multiple candidates to tie using this function,
  since the required percentage to win must be greater than fifty percent.
  """
  @spec instant_runoff(Enumerable.t(), Keyword.t()) :: any()
  def instant_runoff(ranked_votes, opts \\ []) do
    do_instant_runoff(ranked_votes, [], opts)
  end

  defp do_instant_runoff(ranked_votes, losers, opts) do
    tallies =
      Stream.map(ranked_votes, fn vote ->
        vote
        |> Enum.drop_while(&(&1 in losers))
        |> Enum.at(0)
      end)
      |> Enum.frequencies()

    {first_key, first_val} = Enum.at(tallies, 0)

    {worst_candidates, _worst_votes, best_candidates, best_votes, total_votes} =
      Map.drop(tallies, [first_key])
      |> Enum.reduce({[first_key], first_val, [first_key], first_val, first_val}, fn {next_key, next_val}, {lowest_keys, lowest_val, highest_keys, highest_val, total_votes} ->
        cond do
          next_val == highest_val -> {lowest_keys, lowest_val, [next_key | highest_keys], highest_val, total_votes + next_val}
          next_val > highest_val -> {lowest_keys, lowest_val, [next_key], next_val, total_votes + next_val}
          next_val == lowest_val -> {[next_key | lowest_keys], lowest_val, highest_keys, highest_val, total_votes + next_val}
          next_val < lowest_val -> {[next_key], next_val, highest_keys, highest_val, total_votes + next_val}
          true -> {lowest_keys, lowest_val, highest_keys, highest_val, total_votes + next_val}
        end
      end)

    best_percentage = best_votes / total_votes * 100
    win_percentage = Keyword.get(opts, :win_percentage, 50.0)

    cond do
      win_percentage > 100.0 ->
        raise "Instant runoff win percentage cannot be higher than 100, but was #{inspect win_percentage}"
      win_percentage < 50.0 ->
        raise "Instant runoff win percentage must be greater than or equal to 50, but was #{inspect win_percentage}"
      true -> nil
    end

    if best_percentage > win_percentage do
      # There can't possibly be a tie, this just unwraps the list
      winner_or_tie(best_candidates)
    else
      do_instant_runoff(ranked_votes, worst_candidates ++ losers, opts)
    end
  end

  @doc """
  Ranked voting with higher ranks meaning higher scores.

  Each vote grants points to all candidates based on their rank in the vote.
  For example, in this vote:

      ["A", "B"]

  Candidate `"A"` is granted two points, and candidate `"B"` is granted one point.

  ## Examples

  In this example, candidate `"B"` wins with five points.
  Candidate `"A"` is in second place with four points,
  and candidate `"C"` is last with three points.

      iex> votes = [
      ...>   ["A", "B", "C"],
      ...>   ["B", "C", "A"],
      ...> ]
      iex> Ballot.borda(votes)
      "B"

  You also start the counting at zero, instead of one, so the last place choice gets zero points.
  In the previous example, the winner is the same, but the points end up different.
  Candidate `"B"` still wins, but with three points,
  candidate `"A"` gets two points, and candidate `"C"` gets one point.

      iex> votes = [
      ...>   ["A", "B", "C"],
      ...>   ["B", "C", "A"],
      ...> ]
      iex> Ballot.borda(votes, starting_at: 0)
      "B"

  Returns a list in case of ties.

      iex> votes = [
      ...>   ["A", "C"],
      ...>   ["B", "D"],
      ...> ]
      iex> Ballot.borda(votes) |> Enum.sort()
      ["A", "B"]
  """
  @spec borda(Enumerable.t(), Keyword.t()) :: any()
  def borda(ranked_votes, opts \\ []) do
    starting_at = Keyword.get(opts, :starting_at, 1)
    if starting_at not in [0, 1] do
      raise ":starting_at must be 0 or 1"
    end

    ranked_votes
    |> Stream.flat_map(fn vote ->
      Enum.reverse(vote)
      |> Stream.with_index()
      |> Stream.map(fn {choice, index} -> {choice, index + starting_at} end)
    end)
    |> all_max_scores()
    |> winner_or_tie()
  end

  @doc """
  Ranked voting with fractionally decreasing scores.

  Similar to `borda/1`, but instead of granting *more* points to higher ranks,
  it awards *fractionally smaller* amounts of points to lower ranks.
  In a ballot with five candidates:
  - 1st earns 1.00 points
  - 2nd choice earns 0.50 points
  - 3rd choice earns 0.33 points
  - 4th choice earns 0.25 points
  - 5th choice earns 0.20 points

  For the nth position on the ballot (starting at one), the candidate will earn `1 / n` points.

  ## Examples

  In this example, `"B"` earns 1.50 points, `"A"` earns 1.33 points, and `"C"` earns 0.88 points.

      iex> votes = [
      ...>   ["A", "B", "C"],
      ...>   ["B", "C", "A"],
      ...> ]
      iex> Ballot.dowdall(votes)
      "B"

  Returns a list in case of ties.

      iex> votes = [
      ...>   ["A", "C"],
      ...>   ["B", "D"],
      ...> ]
      iex> Ballot.dowdall(votes) |> Enum.sort()
      ["A", "B"]
  """
  @spec dowdall(Enumerable.t()) :: any()
  def dowdall(ranked_votes) do
    ranked_votes
    |> Stream.flat_map(fn vote ->
      Stream.with_index(vote)
      |> Stream.map(fn {choice, index} ->
        {choice, 1 / (index + 1)}
      end)
    end)
    |> all_max_scores()
    |> winner_or_tie()
  end

  @doc """
  Counts the number of approvals of each candidate.

  This is different from ranked-choice counting strategies
  because candidates are not ranked among one another,
  and the voter only chooses the candidates they approve of.
  ## Examples

  Candidate `"B"` wins because it has two approvals,
  whereas candidates `"A"` and `"C"` only have one.

      iex> votes = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> Ballot.approval(votes)
      "B"

  Each ballot can only approve of any candidate once.

      iex> votes = [
      ...>   ["A", "A", "A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> Ballot.approval(votes)
      "B"

  Using `MapSet`s for each ballot would not be out-of-place here.

      iex> votes = [
      ...>   MapSet.new(["A", "A", "A", "B"]),
      ...>   MapSet.new(["B", "C"]),
      ...> ]
      iex> Ballot.approval(votes)
      "B"

  Returns a list in case of ties.

      iex> votes = [
      ...>   ["A", "C"],
      ...>   ["B", "D"],
      ...> ]
      iex> Ballot.approval(votes) |> Enum.sort()
      ["A", "B", "C", "D"]
  """
  @spec approval(Enumerable.t()) :: any()
  def approval(approval_votes) do
    approval_votes
    |> Stream.flat_map(&Stream.uniq/1)
    |> Stream.map(&{&1, 1})
    |> all_max_scores()
    |> winner_or_tie()
  end

  @doc """
  Tallies each candidate's average score.

  Each vote is a map of the candidate to their score.
  Scores can be any numeric value, and the candidate with the highest average is the winner.

  ## Examples

  In this example, candidate `"B"` wins with an average rating of 4.
  Candidate `"A"` ends with a score of 3, and `"C"` with a score of 1.

      iex> votes = [
      ...>   %{"A" => 5, "B" => 4, "C" => 1},
      ...>   %{"A" => 1, "B" => 4, "C" => 1},
      ...> ]
      iex> Ballot.score(votes)
      "B"

  Returns a list in case of ties.

      iex> votes = [
      ...>   %{"A" => 5, "B" => 5, "C" => 1},
      ...>   %{"A" => 5, "B" => 5, "C" => 1},
      ...> ]
      iex> Ballot.score(votes) |> Enum.sort()
      ["A", "B"]
  """
  @spec score(Enumerable.t()) :: any()
  def score(score_votes) do
    score_votes
    |> Stream.flat_map(&Map.to_list/1)
    |> all_max_scores()
    |> winner_or_tie()
  end

  defp winner_or_tie([winner]), do: winner
  defp winner_or_tie(results) when is_list(results), do: results

  defp all_max_scores(scores) do
    [{first_key, first_score}] = Stream.take(scores, 1) |> Enum.to_list()
    rest = Stream.drop(scores, 1)
    {_scores, winners, _winning_score} =
      Enum.reduce(rest, {%{first_key => first_score}, [first_key], first_score}, fn {candidate, score}, {scores, winners, winning_score} ->
        {new_score, scores} = Map.get_and_update(scores, candidate, fn current_score ->
          new_score =
            if is_nil(current_score) do
              score
            else
              current_score + score
            end

          {new_score, new_score}
        end)

        cond do
          new_score == winning_score -> {scores, [candidate | winners], winning_score}
          new_score > winning_score -> {scores, [candidate], new_score}
          new_score < winning_score -> {scores, winners, winning_score}
        end
      end)
    winners
  end
end
