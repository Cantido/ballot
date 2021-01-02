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
      id: Ballot.ID.generate(),
      choices: choices
    }
  end
end
