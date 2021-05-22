defmodule Ballot.ApprovalVote do
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
      id: Ballot.ID.human_readable(),
      choices: choices
    }
  end

  defimpl Ballot.Vote, for: __MODULE__ do
    def candidates(vote) do
      vote.choices
    end
  end
end
