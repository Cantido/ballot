defmodule Mix.Tasks.InstantRunoffExprof do
  @shortdoc "Profile using ExProf"
  use Mix.Task
  import ExProf.Macro

  def run(_mix_args) do
    ballot_examples = [
      ["A", "B", "C", "D"],
      ["B", "C", "D", "A"],
      ["D", "B", "C", "A"],
      ["C", "D", "A", "B"],
    ]

    # Use Enum.to_list() so the counter function doesn't wait on a stream
    ballots =
      Stream.repeatedly(fn ->
        Enum.random(ballot_examples)
      end)
      |> Stream.take(1_000_000)
      |> Enum.to_list()


    profile do: BallotCounter.instant_runoff(ballots)
  end

end
