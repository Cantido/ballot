defmodule Ballot.Vote do
  @moduledoc """
  Behavior for any kind of vote.
  """
  
  @doc """
  Returns a list of all candidates included in this vote in no particular order.
  """
  @callback candidates(any) :: list(String.t())
end
