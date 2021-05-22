defmodule Ballot.ID do
  @doc """
  Generates IDs that should be easy for humans to read and copy.

  These IDs consist of four groups of four characters, separated by a hyphen, for example `abcd-1234-ABCD-wxyz`.
  """
  def human_readable do
    # Check against https://zelark.github.io/nano-id-cc/ to see the collision chance.
    Nanoid.generate(16, "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    |> String.to_charlist()
    |> Enum.chunk_every(4)
    |> Enum.join("-")
  end
end
