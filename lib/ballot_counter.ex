defmodule BallotCounter do
  @moduledoc """
  A ballot-counting library implementing several voting methods.

  Candidates are usually represented by a string, which could be something like your candidate's ID number, or name.
  You can use anything that can be compared by value.

  In the simplest voting system, first-past-the-post AKA plurality voting, these IDs *are* the ballots.
  To count them, put them in a list.

      iex> BallotCounter.plurality(["A", "A", "A", "B", "B"])
      "A"

  More complex ballots are represented by plain Elixir data structures.
  For example, ballots for any ranked-choice voting system, like Instant Runoff,
  are just lists with values at the front of the list being a higher rank than values at the end of the list.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...>   ["C"],
      ...>   ["C"]
      ...> ]
      iex> BallotCounter.instant_runoff(ballots)
      "C"
      iex> BallotCounter.dowdall(ballots)
      "C"
      iex> BallotCounter.borda(ballots) |> Enum.sort()
      ["B", "C"]

  Approval voting is similar, but ballots are lists of all the candidates a voter approves of, so order doesn't matter.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> BallotCounter.approval(ballots)
      "B"

  In score voting, each ballot is a map of candidates to a numeric score.

      iex> ballots = [
      ...>   %{"A" => 5, "B" => 4, "C" => 1},
      ...>   %{"A" => 1, "B" => 4, "C" => 1},
      ...> ]
      iex> BallotCounter.score(ballots)
      "B"

  In case of ties, these functions return a list of all the winners.

      iex> BallotCounter.plurality(["A", "A", "B", "B"]) |> Enum.sort()
      ["A", "B"]

  In case nobody wins, `nil` is returned.

      iex> BallotCounter.quota(["A", "A", "B", "B"], 0.60)
      nil

  All functions in this library expect values that implement `Enumerable`.
  It is entirely possible to pass in a `Stream` of values, and this library uses `Stream` as much as possible,
  so you might get better counting speeds if your data source can be streamed.
  Remember that `Ecto.Repo.stream/2` exists!

      iex> Stream.cycle(["A", "B", "C"])
      ...> |> Stream.take(999)
      ...> |> BallotCounter.plurality()
      ["A", "B", "C"]
  """

  @doc """
  Grants the win to the candidate with the most votes.

  ## Examples

      iex> BallotCounter.plurality(["A", "A", "A", "B", "B"])
      "A"

  Returns a list in case of ties.

      iex> BallotCounter.plurality(["A", "A", "B", "B"]) |> Enum.sort()
      ["A", "B"]
  """
  @spec plurality(Enumerable.t()) :: any()
  def plurality(ballots) do
    votes = Enum.frequencies(ballots)
    {_top_candidate, top_votes_count} = Enum.max_by(votes, &elem(&1, 1))

    # tie detection, select everyone with the top number of votes
    Enum.filter(votes, fn {_c, v} -> v == top_votes_count end)
    |> Enum.map(&elem(&1, 0))
    |> winner_or_tie_or_none()
  end

  @doc """
  Plurality with a minimum percentage of the vote.

  Every candidate that receives greater than `q`% of votes is a winner.

  If the parameter `q` is greater than one, it is assumed to be a percentage.
  Equal to or less than one, it is assumed to be a fraction.

  ## Examples

      iex> ballots = [
      ...>   "A",
      ...>   "A",
      ...>   "B"
      ...> ]
      iex> BallotCounter.quota(ballots, 60)
      "A"
      iex> BallotCounter.quota(ballots, 0.30) |> Enum.sort()
      ["A", "B"]
      iex> BallotCounter.quota(ballots, 70)
      nil

  """
  def quota(ballots, q) when is_number(q) and q > 0 and q <= 100 do
    quota_fraction =
      if q > 1 do
        q / 100
      else
        q
      end

    Enum.frequencies(ballots)
    |> Enum.filter(fn {_candidate, vote_count} ->
      vote_count / Enum.count(ballots) >= quota_fraction
    end)
    |> Enum.map(&elem(&1, 0))
    |> winner_or_tie_or_none()
  end

  @doc """
  Plurality with Ranked-choice characteristics.

  If any candidate does not receive more than 50% of the vote,
  then a runoff is held between the top two candidates.

  ## Examples

  In the simplest case, the candidate with greater than 50% of the first-choice votes wins.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> BallotCounter.plurality_with_runoff(ballots)
      "A"

  If nobody has greater than 50% of the vote,
  there is a runoff between the two candidates with the most highest-rank votes.

  In this example, `"A"` and `"B"` are the top two candidates, but neither has greater than 50% of the vote.
  In a runoff, the last two ballots ends up being votes for `"B"`, so `"B"` wins.

      iex> ballots = [
      ...>   ["A"],
      ...>   ["A"],
      ...>   ["A"],
      ...>   ["B"],
      ...>   ["B"],
      ...>   ["C", "B"],
      ...>   ["D", "B"]
      ...> ]
      iex> BallotCounter.plurality_with_runoff(ballots)
      "B"

  In case of ties before the runoff, the runoff happens between everyone tied for first, and everyone tied for second.
  In this example, `"A"` and `"B"` are tied for first, and `"C"` is in second place.
  However, since all of the ballots at the bottom of list have `"C"` as their second choice, `"C"` ends up the winner.

      iex> ballots = [
      ...>   ["A"],
      ...>   ["A"],
      ...>   ["A"],
      ...>   ["B"],
      ...>   ["B"],
      ...>   ["B"],
      ...>   ["C"],
      ...>   ["C"],
      ...>   ["D", "C"],
      ...>   ["E", "C"],
      ...>   ["F", "C"],
      ...>   ["G", "C"],
      ...>   ["H", "C"]
      ...> ]
      iex> BallotCounter.plurality_with_runoff(ballots)
      "C"
  """
  def plurality_with_runoff(ballots) do
    votes =
      ballots
      |> Enum.map(&Enum.at(&1, 0))
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)

    ballots_count = Enum.count(ballots)

    {top_candidate, top_votes_count} = Enum.at(votes, 0)

    if top_votes_count / ballots_count > 0.50 do
      top_candidate
    else
      tied_winners =
        Enum.take_while(votes, fn {_candidate, votes_count} -> votes_count == top_votes_count end)

      rest = Enum.drop_while(votes, fn {_candidate, votes_count} -> votes_count == top_votes_count end)

      {_second_place_candidate, second_place_votes_count} = Enum.at(rest, 0)

      tied_second_place =
        Enum.take_while(rest, fn {_candidate, votes_count} -> votes_count == second_place_votes_count end)

      runoff_candidates =
        Enum.concat(tied_winners, tied_second_place)
        |> Enum.map(&elem(&1, 0))

      runoff_ballots =
        ballots
        |> Enum.map(fn ballot ->
          Enum.drop_while(ballot, fn candidate ->
              candidate not in runoff_candidates
            end)
          end)
        |> Enum.reject(&Enum.empty?/1)
        |> Enum.map(&Enum.at(&1, 0))

      runoff_votes =
        runoff_ballots
        |> Enum.frequencies()
        |> Enum.sort_by(&elem(&1, 1), :desc)

      {top_runoff_candidate, top_runoff_votes_count} = Enum.at(runoff_votes, 0)

      if top_runoff_votes_count / Enum.count(runoff_ballots) > 0.50 do
        top_runoff_candidate
      else
        nil
      end
    end
  end

  @doc """
  The quintessential ranked voting strategy.

  Counts first place votes, and if the winner has more than 50% of the vote, they win.
  If not, the candidate with the least number of first-choice votes is dropped,
  and the ballots are tallied again,
  this time taking the second choice of any votes that had the loser first.
  Ties for last place result in multiple candidates being removed in one round.

  This method is also called Hare Rule, Ranked-Choice, and Alternative Vote.

  ## Examples

  In the simplest case, the candidate with more than fifty percent of the
  first-choice ballots wins.

    iex> ballots = [
    ...>   ["A"],
    ...>   ["A"],
    ...>   ["B"]
    ...> ]
    iex> BallotCounter.instant_runoff(ballots)
    "A"

  If no candidate got at least fifty percent of the vote,
  the candidate with the smallest amount of votes is eliminated.
  This means you look to the second choice on any ballots that have that
  candidate as first choice.

  In this example, no candidates win on the first pass,
  as `"C"` does not have *greater than fifty percent* of the vote.
  Candidates `"A"` and `"B"` will lose the first round.
  Votes with `"A"` and `"B"` first will then fall back to their next choice,
  granting `"C"` the victory with four out of four votes.

      iex> ballots = [
      ...>   ["A", "C"],
      ...>   ["B", "C"],
      ...>   ["C"],
      ...>   ["C"]
      ...> ]
      iex> BallotCounter.instant_runoff(ballots)
      "C"

  You can also pass in a required win percentage greater than 50.0,
  and less than or equal to 100.
  In this case, candidates `"B"`, `"C"`, and `"D"` lose the first round,
  and their votes are now for `"F"`.
  In the second round, `"A"` then loses, and their votes count for `"F"`.
  Candidate `"F"` then wins.

      iex> ballots = [
      ...>   ["A", "F"],
      ...>   ["A", "F"],
      ...>   ["A", "F"],
      ...>   ["B", "F"],
      ...>   ["C", "F"],
      ...>   ["D", "F"],
      ...>   ["E", "F"],
      ...> ]
      iex> BallotCounter.instant_runoff(ballots, required_percentage: 75.0)
      "F"

  It is impossible for multiple candidates to tie using this function,
  since the required percentage to win must be greater than fifty percent.
  """
  @spec instant_runoff(Enumerable.t(), Keyword.t()) :: any()
  def instant_runoff(ballots, opts \\ []) do
    do_instant_runoff(ballots, [], opts)
  end

  defp do_instant_runoff(ballots, losers, opts) do
    tallies =
      Stream.map(ballots, fn ballot ->
        ballot
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
      winner_or_tie_or_none(best_candidates)
    else
      do_instant_runoff(ballots, worst_candidates ++ losers, opts)
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

      iex> ballots = [
      ...>   ["A", "B", "C"],
      ...>   ["B", "C", "A"],
      ...> ]
      iex> BallotCounter.borda(ballots)
      "B"

  You also start the counting at zero, instead of one, so the last place choice gets zero points.
  In the previous example, the winner is the same, but the points end up different.
  Candidate `"B"` still wins, but with three points,
  candidate `"A"` gets two points, and candidate `"C"` gets one point.

      iex> ballots = [
      ...>   ["A", "B", "C"],
      ...>   ["B", "C", "A"],
      ...> ]
      iex> BallotCounter.borda(ballots, starting_at: 0)
      "B"

  Returns a list in case of ties.

      iex> ballots = [
      ...>   ["A", "C"],
      ...>   ["B", "D"],
      ...> ]
      iex> BallotCounter.borda(ballots) |> Enum.sort()
      ["A", "B"]
  """
  @spec borda(Enumerable.t(), Keyword.t()) :: any()
  def borda(ballots, opts \\ []) do
    starting_at = Keyword.get(opts, :starting_at, 1)
    if starting_at not in [0, 1] do
      raise ":starting_at must be 0 or 1"
    end

    ballots
    |> Stream.flat_map(fn ballot ->
      Enum.reverse(ballot)
      |> Enum.with_index()
      |> Enum.map(fn {candidate, index} -> {candidate, index + starting_at} end)
    end)
    |> all_max_scores()
    |> winner_or_tie_or_none()
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

      iex> ballots = [
      ...>   ["A", "B", "C"],
      ...>   ["B", "C", "A"],
      ...> ]
      iex> BallotCounter.dowdall(ballots)
      "B"

  Returns a list in case of ties.

      iex> ballots = [
      ...>   ["A", "C"],
      ...>   ["B", "D"],
      ...> ]
      iex> BallotCounter.dowdall(ballots) |> Enum.sort()
      ["A", "B"]
  """
  @spec dowdall(Enumerable.t()) :: any()
  def dowdall(ballot) do
    ballot
    |> Enum.flat_map(fn ballot ->
      Enum.with_index(ballot)
      |> Enum.map(fn {candidate, index} ->
        {candidate, 1 / (index + 1)}
      end)
    end)
    |> all_max_scores()
    |> winner_or_tie_or_none()
  end

  @doc """
  Ranked-choice that drops candidates with the most last-place votes.any()

  ## Examples

  If a candidate receives over 50% of the first-choice votes, that candidate wins.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> BallotCounter.coombs(ballots)
      "A"

  If there is no candidate with a strict majority of first-place votes,
  the candidate with the most last-place votes is dropped, and the election is held again.
  In this example, no candidate has a strict first-place majority.
  So, candidate `"B"` is deleted, since it received the most last-place votes, and the election is held again.
  Candidate `"A"` then wins.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["A", "B"],
      ...>   ["A", "B"],
      ...>   ["B", "A"],
      ...>   ["C", "D"],
      ...>   ["D", "C"],
      ...> ]
      iex> BallotCounter.coombs(ballots)
      "A"

  This will happen repeatedly until a winner is found, or nobody wins.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...>   ["C", "A"],
      ...> ]
      iex> BallotCounter.coombs(ballots)
      nil
  """
  @spec coombs(Enumerable.t()) :: any()
  def coombs(ballots) do
    do_coombs(ballots, [])
  end

  defp do_coombs(ballots, losers) do
    ballots_without_losers =
      Enum.map(ballots, fn ballot ->
        Enum.reject(ballot, &(&1 in losers))
      end)
      |> Enum.reject(&Enum.empty?/1)

    if Enum.empty?(ballots_without_losers) do
      nil
    else

      votes =
        ballots_without_losers
        |> Enum.map(&Enum.at(&1, 0))
        |> Enum.frequencies()
        |> Enum.sort_by(&elem(&1, 1), :desc)

      ballots_count = Enum.count(ballots_without_losers)

      {top_candidate, top_votes_count} = Enum.at(votes, 0)

      if top_votes_count / ballots_count > 0.50 do
        top_candidate
      else
        last_place_votes =
          ballots_without_losers
          |> Enum.map(&Enum.reverse/1)
          |> Enum.map(&Enum.at(&1, 0))
          |> Enum.frequencies()
          |> Enum.sort_by(&elem(&1, 1), :desc)

        {_loser, worst_votes_count} = Enum.at(last_place_votes, 0)

        # detect all losers for last place
        new_losers = Enum.filter(last_place_votes, fn {_loser, votes_count} ->
          votes_count == worst_votes_count
        end)
        |> Enum.map(&elem(&1, 0))

        do_coombs(ballots, new_losers ++ losers)
      end
    end
  end

  @doc """
  Counts the number of approvals of each candidate.

  This is different from ranked-choice counting strategies
  because candidates are not ranked among one another,
  and the voter only chooses the candidates they approve of.

  ## Examples

  Candidate `"B"` wins because it has two approvals,
  whereas candidates `"A"` and `"C"` only have one.

      iex> ballots = [
      ...>   ["A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> BallotCounter.approval(ballots)
      "B"

  Each ballot can only approve of any candidate once.

      iex> ballots = [
      ...>   ["A", "A", "A", "B"],
      ...>   ["B", "C"],
      ...> ]
      iex> BallotCounter.approval(ballots)
      "B"

  Using `MapSet`s for each ballot would not be out-of-place here.

      iex> ballots = [
      ...>   MapSet.new(["A", "A", "A", "B"]),
      ...>   MapSet.new(["B", "C"]),
      ...> ]
      iex> BallotCounter.approval(ballots)
      "B"

  Returns a list in case of ties.

      iex> ballots = [
      ...>   ["A", "C"],
      ...>   ["B", "D"],
      ...> ]
      iex> BallotCounter.approval(ballots) |> Enum.sort()
      ["A", "B", "C", "D"]
  """
  @spec approval(Enumerable.t()) :: any()
  def approval(ballots) do
    ballots
    |> Enum.flat_map(&Enum.uniq/1)
    |> Enum.map(&{&1, 1})
    |> all_max_scores()
    |> winner_or_tie_or_none()
  end

  @doc """
  Tallies each candidate's average score.

  Each ballot is a map of the candidate to their score.
  Scores can be any numeric value, and the candidate with the highest average is the winner.

  ## Examples

  In this example, candidate `"B"` wins with an average rating of 4.
  Candidate `"A"` ends with a score of 3, and `"C"` with a score of 1.

      iex> ballots = [
      ...>   %{"A" => 5, "B" => 4, "C" => 1},
      ...>   %{"A" => 1, "B" => 4, "C" => 1},
      ...> ]
      iex> BallotCounter.score(ballots)
      "B"

  Returns a list in case of ties.

      iex> ballots = [
      ...>   %{"A" => 5, "B" => 5, "C" => 1},
      ...>   %{"A" => 5, "B" => 5, "C" => 1},
      ...> ]
      iex> BallotCounter.score(ballots) |> Enum.sort()
      ["A", "B"]
  """
  @spec score(Enumerable.t()) :: any()
  def score(ballots) do
    ballots
    |> Stream.flat_map(&Map.to_list/1)
    |> all_max_scores()
    |> winner_or_tie_or_none()
  end

  @doc """
  A score voting scheme using the score median, not mean.

  ## Examples

  In this example, `"A"` has a mean score of 2.6, and would win if this was normal score voting.
  However, since we are looking at the median, `"B"`'s median of 3 makes them the winner.

      iex> ballots = [
      ...>   %{"A" => 4, "B" => 3, "C" => 1},
      ...>   %{"A" => 4, "B" => 3, "C" => 2},
      ...>   %{"A" => 2, "B" => 0, "C" => 3},
      ...>   %{"A" => 2, "B" => 3, "C" => 4},
      ...>   %{"A" => 1, "B" => 0, "C" => 2},
      ...> ]
      iex> BallotCounter.majority_judgement(ballots)
      "B"

  Returns a list in case of a tie.

      iex> ballots = [
      ...>   %{"A" => 4, "B" => 4, "C" => 1},
      ...>   %{"A" => 4, "B" => 4, "C" => 2}
      ...> ]
      iex> BallotCounter.majority_judgement(ballots) |> Enum.sort()
      ["A", "B"]
  """
  def majority_judgement(ballots) do
    score_medians =
      Enum.flat_map(ballots, &Map.to_list/1)
      |> Enum.reduce(%{}, fn {candidate, score}, scores ->
        Map.update(scores, candidate, [score], &[score | &1])
      end)
      |> Enum.map(fn {candidate, scores} ->
        {candidate, median(scores)}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)

    {_, top_score} = Enum.at(score_medians, 0)

    Enum.filter(score_medians, fn {_candidate, score} ->
      score == top_score
    end)
    |> Enum.map(&elem(&1, 0))
    |> winner_or_tie_or_none()
  end

  defp median(values) do
    count = Enum.count(values)

    if count == 0 do
      raise Enum.EmptyError
    end

    i = div(count, 2)

    sorted = Enum.sort(values)

    if rem(count, 2) == 1 do
      Enum.at(sorted, i)
    else
      (Enum.at(sorted, i - 1) + Enum.at(sorted, i)) / 2
    end
  end

  defp winner_or_tie_or_none([]), do: nil
  defp winner_or_tie_or_none([winner]), do: winner
  defp winner_or_tie_or_none(results) when is_list(results), do: results

  defp all_max_scores(scores) do
    [{first_candidate, first_score}] = Stream.take(scores, 1) |> Enum.to_list()
    rest = Stream.drop(scores, 1)
    {_scores, winners, _winning_score} =
      Enum.reduce(rest, {%{first_candidate => first_score}, [first_candidate], first_score}, fn {candidate, score}, {scores, winners, winning_score} ->
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
          true -> {scores, winners, winning_score}
        end
      end)
    winners
  end
end
