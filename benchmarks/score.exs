ballot_examples = [
  %{a: 5, b: 3, c: 1},
  %{a: 1, b: 5, c: 3},
  %{a: 3, b: 1, c: 5}
]

Benchee.run(
  %{
    "BallotCounter" => fn ballots -> BallotCounter.score(ballots) end
  },
  inputs: %{
    "list" => Stream.cycle(ballot_examples) |> Stream.take(1_000_000) |> Enum.to_list(),
    "stream" => Stream.cycle(ballot_examples) |> Stream.take(1_000_000),
    "stream with 1ms delay" => Stream.interval(1) |> Stream.map(fn i -> Enum.at(ballot_examples, rem(i, 3)) end) |> Stream.take(100)
  }
)
