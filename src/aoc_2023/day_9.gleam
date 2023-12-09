import gleam/int
import gleam/list
import gleam/string
import common
import gleam/pair

type HistoryLine =
  List(#(Int, Int))

type Histories =
  List(HistoryLine)

fn parse_history_line(input: String) -> HistoryLine {
  input
  |> string.split(" ")
  |> list.map(int.parse)
  |> list.map(common.unwrap_panic)
  |> list.window_by_2
}

fn parse_history_line_reverse(input: String) -> HistoryLine {
  input
  |> string.split(" ")
  |> list.reverse
  |> list.map(int.parse)
  |> list.map(common.unwrap_panic)
  |> list.window_by_2
}

fn parse_histories(input: String) -> Histories {
  input
  |> string.split("\n")
  |> list.map(parse_history_line)
}

fn parse_histories_reverse(input: String) -> Histories {
  input
  |> string.split("\n")
  |> list.map(parse_history_line_reverse)
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
      let last =
        differences
        |> list.last
        |> common.unwrap_panic

      calculate_next(
        differences
        |> list.window_by_2,
      )
      |> int.add(last)
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
  |> parse_histories
  |> list.map(get_next_in_sequence)
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> parse_histories_reverse
  |> list.map(get_next_in_sequence)
  |> int.sum
}
