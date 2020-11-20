defmodule Ballot.ApprovalVote do
  @enforce_keys [
    :choices
  ]
  defstruct [
    choices: []
  ]

  def new(choices) do
    %__MODULE__{
      choices: choices
    }
  end
end
