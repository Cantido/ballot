defmodule Ballot.ScoreVote.CandidateScore do
  @enforce_keys [
    :candidate,
    :score
  ]
  defstruct [
    :candidate,
    :score
  ]
end

defmodule Ballot.ScoreVote do

  alias Ballot.ScoreVote.CandidateScore

  @behaviour Ballot.Vote

  @enforce_keys [
    :id,
    :scores
  ]
  defstruct [
    id: nil,
    scores: []
  ]

  @doc """
  Accepts a map of scores, where the key is the candidate ID, and the value is the score.
  """
  def new(scores) do
    score_structs =
      scores
      |> Enum.map(fn {candidate_id, score} ->
        %CandidateScore{
          candidate: candidate_id,
          score: score
        }
      end)

    %__MODULE__{
      id: Ballot.ID.generate(),
      scores: score_structs
    }
  end

  def candidates(vote) do
    Enum.map(vote.scores, & &1.candidate)
  end
end
