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

  defimpl Ballot.Vote do
    def candidates(vote) do
      vote.choices
    end

    def id(vote) do
      vote.id
    end
  end
end
