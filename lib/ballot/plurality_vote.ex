defmodule Ballot.PluralityVote do
  @enforce_keys [
    :choice
  ]
  defstruct [
    :choice
  ]

  def new(choice) do
    %__MODULE__{
      choice: choice
    }
  end

  defimpl Ballot.Vote do
    def candidates(vote) do
      [vote.choice]
    end
  end
end
