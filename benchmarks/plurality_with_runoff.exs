ballot_examples = [[:a, :b], [:b, :c], [:c, :a]]

Benchee.run(
  %{
    "BallotCounter" => fn ballots -> BallotCounter.plurality_with_runoff(ballots) end
  },
  inputs: %{
    "list" => Stream.cycle(ballot_examples) |> Stream.take(1_000_000) |> Enum.to_list(),
    "stream" => Stream.cycle(ballot_examples) |> Stream.take(1_000_000),
    "stream with 1ms delay" => Stream.interval(1) |> Stream.map(fn i -> Enum.at(ballot_examples, rem(i, 3)) end) |> Stream.take(100)
  }
)
