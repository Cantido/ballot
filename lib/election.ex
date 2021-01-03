defmodule Ballot.Election do
  @enforce_keys [
    :candidates
  ]
  defstruct [
    candidates: [],
    votes: []
  ]

  def new(candidates) do
    %__MODULE__{
      candidates: MapSet.new(candidates)
    }
  end

  @doc """
  Add a vote to an election.
  """
  def cast(election, vote) do
    cond do
      not valid_vote_type?(election, vote) -> {:error, :wrong_vote_type}
      duplicate_vote?(election, vote) -> {:error, :duplicate_vote}
      not vote_for_candidates_in_election?(election, vote) -> {:error, :candidate_not_in_election}
      true ->
        updated_election =
          Map.update!(election, :votes, fn votes ->
            [vote | votes]
          end)

        {:ok, updated_election}
    end
  end

  defp valid_vote_type?(election, vote) do
    if Enum.count(election.votes) > 0 do
      first_vote_type = List.first(election.votes).__struct__
      new_vote_type = vote.__struct__

      first_vote_type == new_vote_type
    else
      true
    end
  end

  defp duplicate_vote?(election, vote) do
    vote_ids = Enum.into(election.votes, MapSet.new(), &Map.get(&1, :id))
    MapSet.member?(vote_ids, vote.id)
  end

  defp vote_for_candidates_in_election?(election, vote) do
    vote_candidates = vote.__struct__.candidates(vote) |> MapSet.new()
    MapSet.subset?(vote_candidates, election.candidates)
  end
end
