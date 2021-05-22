defmodule Ballot.PluralityVote do
  @enforce_keys [
    :id,
    :choice
  ]
  defstruct [
    :id,
    :choice
  ]

  def new(choice) do
    %__MODULE__{
      id: Ballot.ID.human_readable(),
      choice: choice
    }
  end

  defimpl Ballot.Vote, for: __MODULE__ do
    def candidates(vote) do
      [vote.choice]
    end
  end
end
