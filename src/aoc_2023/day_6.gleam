import gleam/int
import gleam/list
import gleam/string
import gleam/regex
import gleam/result
import gleam/option
import common
import gleam/pair
import gleam/io

// #(duration ms, distance mm)
type RaceOutcome =
  #(Int, Int)

pub const charge_ratio_part_one = 1

fn parse_line_part_one(line: String) {
  let assert Ok(line_parser) = regex.from_string(".+:.+?(\\d.+)")

  case regex.scan(line_parser, line) {
    [regex.Match(_, sb)] ->
      case sb {
        [option.Some(digit_line)] ->
          digit_line
          |> string.split(" ")
          |> list.filter(fn(x) { !string.is_empty(x) })
          |> list.map(int.parse)
          |> result.values
      }
  }
}

fn parse_line_part_two(line: String) {
  let assert Ok(line_parser) = regex.from_string(".+:.+?(\\d.+)")

  case regex.scan(line_parser, line) {
    [regex.Match(_, sb)] ->
      case sb {
        [option.Some(digit_line)] ->
          digit_line
          |> string.split("")
          |> list.filter(fn(x) { !string.is_empty(x) })
          |> list.map(int.parse)
          |> result.values
          |> int.undigits(10)
          |> common.unwrap_panic
          |> fn(x) { [x] }
      }
  }
}

fn lines_into_races(lines: #(List(Int), List(Int))) {
  lines.0
  |> list.zip(lines.1)
}

fn parse_input_into_race_outcomes(
  input: String,
  line_parser: fn(String) -> List(Int),
) -> List(RaceOutcome) {
  input
  |> string.split("\n")
  |> list.map(line_parser)
  |> common.pair_of_list
  |> common.unwrap_panic
  |> lines_into_races
}

fn solve_race_outcome_naive(outcome: RaceOutcome, charge_ratio: Int) -> Int {
  list.range(0, outcome.0)
  |> list.map(fn(hold_time) {
    let speed = hold_time * charge_ratio
    let remaining_time = outcome.0 - hold_time

    remaining_time * speed
  })
  |> list.filter(fn(distance_travelled) { distance_travelled > outcome.1 })
  |> list.length
}

pub fn pt_1(input: String) {
  input
  |> parse_input_into_race_outcomes(parse_line_part_one)
  |> list.map(fn(x) { solve_race_outcome_naive(x, charge_ratio_part_one) })
  |> list.fold(1, int.multiply)
}

pub fn pt_2(input: String) {
  input
  |> parse_input_into_race_outcomes(parse_line_part_two)
  |> io.debug
  |> list.map(fn(x) { solve_race_outcome_naive(x, charge_ratio_part_one) })
  |> list.fold(1, int.multiply)
}
