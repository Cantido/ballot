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
      candidates: candidates
    }
  end

  @doc """
  Add a vote to an election.
  """
  def vote(election, vote) do
    if Enum.count(election.votes) > 0 do
      first_vote_type = List.first(election.votes).__struct__
      new_vote_type = vote.__struct__

      unless first_vote_type == new_vote_type do
        raise "Cannot mix vote types. Given election had a vote of type #{first_vote_type} but was given a new vote of type #{new_vote_type}."
      end
    end

    Map.update!(election, :votes, fn votes ->
      [vote | votes]
    end)
  end
end
