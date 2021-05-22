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
      id: Ballot.ID.human_readable(),
      choices: candidate_ids
    }
  end

  defimpl Ballot.Vote, for: __MODULE__ do
    def candidates(vote) do
      vote.choices
    end

    def id(vote) do
      vote.id
    end
  end
end
