defmodule Ballot.RankedVote do
  @moduledoc """
  A vote where candidates are put in absolute order from most desirable to least desirable,
  i.e. `[first_choice, second_choice, third_choice]`, etc.
  """
  @enforce_keys [
    :id,
    :choices
  ]
  defstruct [
    id: nil,
    choices: []
  ]
  @doc """
  Create a new ranked-choice vote.

  Argument is a list of candidates in order from most desirable to least desirable,
  i.e. `[first_choice, second_choice, third_choice]`, etc.
  """
  def new(candidate_ids) do
    %__MODULE__{
      id: Ballot.ID.generate(),
      choices: candidate_ids
    }
  end
end
