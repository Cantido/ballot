defprotocol Ballot.Vote do
  @moduledoc """
  Functions for working with votes
  """

  @doc """
  Returns a list of all candidates included in this vote in no particular order.
  """
  def candidates(vote)

  @doc """
  Returns the vote's unique ID.
  """
  def id(vote)
end
