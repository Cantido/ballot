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
    Map.update!(election, :votes, fn votes ->
      [vote | votes]
    end)
  end
end
