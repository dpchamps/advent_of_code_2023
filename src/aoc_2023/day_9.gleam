import gleam/int
import gleam/list
import gleam/string
import common
import gleam/pair

type HistoryLine =
  List(#(Int, Int))

type Histories =
  List(HistoryLine)

fn parse_history_line(
  txfm: fn(List(String)) -> List(String),
) -> fn(String) -> HistoryLine {
  fn(input: String) {
    input
    |> string.split(" ")
    |> txfm
    |> list.map(int.parse)
    |> list.map(common.unwrap_panic)
    |> list.window_by_2
  }
}

fn parse_histories(
  input: String,
  parser: fn(String) -> HistoryLine,
) -> Histories {
  input
  |> string.split("\n")
  |> list.map(parser)
}

fn difference_of_pair(x: #(Int, Int)) {
  x.1 - x.0
}

fn calculate_next(history_line: HistoryLine) -> Int {
  let differences =
    history_line
    |> list.map(difference_of_pair)
  case
    differences
    |> list.all(fn(x) { x == 0 })
  {
    True -> 0
    False -> {
      differences
      |> list.last
      |> common.unwrap_panic
      |> int.add(calculate_next(
        differences
        |> list.window_by_2,
      ))
    }
  }
}

fn get_next_in_sequence(sequence: HistoryLine) -> Int {
  let last =
    sequence
    |> list.last
    |> common.unwrap_panic
    |> pair.second

  sequence
  |> calculate_next
  |> int.add(last)
}

pub fn pt_1(input: String) {
  input
  |> parse_histories(parse_history_line(common.identity))
  |> list.map(get_next_in_sequence)
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> parse_histories(parse_history_line(list.reverse))
  |> list.map(get_next_in_sequence)
  |> int.sum
}
