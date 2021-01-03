defmodule Ballot.PluralityVote do
  @behaviour Ballot.Vote

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

  @doc """
  Returns a list of all candidates included in this vote in no particular order.
  """
  def candidates(vote) do
    [vote.choice]
  end
end
