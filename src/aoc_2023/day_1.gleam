import gleam/string
import gleam/io
import gleam/list
import gleam/int
import gleam/result
import gleam/option
import gleam/pair

fn line_to_num_part_one(line: String) {
  line
  |> string.to_graphemes
  |> list.fold(
    [],
    fn(num_string, grapheme) {
      case int.parse(grapheme) {
        Ok(_) -> list.append(num_string, [grapheme])
        _ -> num_string
      }
    },
  )
  |> fn(val) { [list.first(val), list.last(val)] }
  |> list.filter_map(fn(x) { x })
  |> list.fold("", fn(acc, x) { acc <> x })
  |> int.parse
  |> result.unwrap(-999_999_999)
}

pub fn pt_1(input: String) {
  input
  |> string.split("\n")
  |> list.map(line_to_num_part_one)
  |> int.sum
}

fn string_digit(input: String) -> option.Option(String) {
  case string.lowercase(input) {
    "one" -> option.Some("1")
    "two" -> option.Some("2")
    "three" -> option.Some("3")
    "four" -> option.Some("4")
    "five" -> option.Some("5")
    "six" -> option.Some("6")
    "seven" -> option.Some("7")
    "eight" -> option.Some("8")
    "nine" -> option.Some("9")
    _ -> option.None
  }
}

fn substring_search(
  line: String,
  start_idx: Int,
) -> #(String, option.Option(Int)) {
  line
  |> string.to_graphemes
  |> list.split(start_idx)
  |> pair.second
  |> list.index_fold(
    #("", option.None),
    fn(acc_inner, el_inner, idx_inner) {
      case acc_inner.1 {
        option.Some(_) -> acc_inner
        _ -> {
          let maybe_digit = acc_inner.0 <> el_inner
          let skip_until = start_idx + string.length(maybe_digit) - 1

          case string_digit(maybe_digit) {
            option.Some(sd) -> #(sd, option.Some(skip_until))
            _ -> #(maybe_digit, option.None)
          }
        }
      }
    },
  )
}

fn expand_digits_in_string(line: String) -> String {
  line
  |> string.to_graphemes
  |> list.index_fold(
    #("", option.None),
    fn(acc, el, idx_outer) {
      case acc.1 {
        _ -> {
          case substring_search(line, idx_outer) {
            #(sd, option.Some(idx)) -> #(acc.0 <> sd, option.Some(idx))
            _ -> #(acc.0 <> el, option.None)
          }
        }
      }
    },
  )
  |> pair.first
}

pub fn pt_2(input: String) {
  input
  |> string.split("\n")
  |> list.map(expand_digits_in_string)
  |> list.map(line_to_num_part_one)
  |> int.sum
}
