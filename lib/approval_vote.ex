defmodule Ballot.ApprovalVote do
  @behaviour Ballot.Vote
  
  @enforce_keys [
    :id,
    :choices
  ]
  defstruct [
    id: nil,
    choices: []
  ]

  def new(choices) do
    %__MODULE__{
      id: Ballot.ID.generate(),
      choices: choices
    }
  end

  @doc """
  Returns a list of all candidates included in this vote in no particular order.
  """
  def candidates(vote) do
    vote.choices
  end
end
