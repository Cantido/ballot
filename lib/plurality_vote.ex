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
      id: Ballot.ID.generate(),
      choice: choice
    }
  end
end
