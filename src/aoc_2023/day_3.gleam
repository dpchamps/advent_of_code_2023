import gleam/string
import gleam/regex
import gleam/list
import gleam/int
import gleam/dict
import gleam/result
import gleam/iterator
import gleam/option
import gleam/pair

pub type Item {
  Empty
  Number(Int)
  Symbol(String)
}

fn map_lines_to_coord_set(row: Int, line: String) -> List(#(Int, Int, Item)) {
  let line_len = string.length(line)
  let graphemes =
    line
    |> string.to_graphemes
    |> list.index_map(fn(col, char) {
      case char {
        "." -> #(row, col, Empty)
        _ ->
          case int.parse(char) {
            Ok(digit) -> #(row, col, Number(digit))
            _ -> #(row, col, Symbol(char))
          }
      }
    })
}

fn index_of(s: String, substring: String) -> option.Option(Int) {
  s
  |> string.to_graphemes
  |> list.index_fold(
    option.None,
    fn(found, el, idx) {
      case found {
        option.Some(x) -> option.Some(x)
        _ -> {
          case string.slice(s, idx, string.length(substring)) {
            result if result == substring -> option.Some(idx)
            _ -> option.None
          }
        }
      }
    },
  )
}

fn replace_first(s: String, substring: String, with: String) -> String {
  s
  |> string.to_graphemes
  |> list.fold(
    #("", False),
    fn(acc, char) {
      case acc.1 {
        True -> #(acc.0 <> char, True)
        False ->
          case
            acc.0
            |> string.contains(substring)
          {
            True -> #(
              acc.0
              |> string.replace(substring, with) <> char,
              True,
            )
            False -> #(acc.0 <> char, False)
          }
      }
    },
  )
  |> pair.first
}

fn iterate_in_circle(lines: List(List(#(Int, Int, x))), source_row, source_col) {
  iterator.range(-1, 1)
  |> iterator.map(fn(col) {
    iterator.range(-1, 1)
    |> iterator.map(fn(row) {
      case
        lines
        |> list.at(row + source_row)
      {
        Ok(rows) ->
          case
            rows
            |> list.at(col + source_col)
          {
            Ok(item) -> {
              option.Some(item.2)
            }
            _ -> option.None
          }
        _ -> option.None
      }
    })
  })
  |> iterator.flatten
  |> iterator.to_list
}

fn is_adjacent_to_number(
  lines: List(List(#(Int, Int, Item))),
  source_row,
  source_col,
) -> Bool {
  iterate_in_circle(lines, source_row, source_col)
  |> list.any(fn(el) {
    case el {
      option.Some(Number(_)) -> True
      _ -> False
    }
  })
}

fn select_adjacent_symbols(
  lines: List(List(#(Int, Int, Item))),
) -> List(#(Int, Int, Item)) {
  lines
  |> list.flatten
  |> list.filter(fn(el) {
    case el {
      #(row, col, Symbol(_)) -> {
        let is_adjacent = is_adjacent_to_number(lines, row, col)
        is_adjacent
      }
      _ -> False
    }
  })
}

fn is_in_range(el: Int, from: Int, to: Int) -> Bool {
  let min_x = el - 1
  let max_x = el + 1

  from <= max_x && to >= min_x
}

fn select_digits_from_symbol(
  symbol: #(Int, Int, Item),
  digit_ranges: List(List(#(Int, Int, Int))),
) -> List(#(#(Int, Int), Int)) {
  iterator.range(-1, 1)
  |> iterator.to_list()
  |> list.flat_map(fn(idx_offset) {
    let row = symbol.0 + idx_offset
    case list.at(digit_ranges, row) {
      Ok(sub_list) -> {
        sub_list
        |> list.filter(fn(digit_col) {
          let in_range = is_in_range(symbol.1, digit_col.0, digit_col.1)

          in_range
        })
        |> list.map(fn(x) { #(#(row, x.0), x.2) })
      }
      _ -> []
    }
  })
}

fn get_indicies_from_line(
  line: String,
  els: List(String),
  indices: List(#(Int, Int, Int)),
) -> List(#(Int, Int, Int)) {
  case els {
    [] -> indices
    [first, ..rest] -> {
      let replace_with =
        first
        |> string.to_graphemes
        |> list.map(fn(_) { "." })
        |> string.join("")
      let assert option.Some(index) = index_of(line, first)
      let assert Ok(index_range) =
        int.parse(first)
        |> result.map(fn(d) { #(index, index + string.length(first) - 1, d) })

      get_indicies_from_line(
        replace_first(line, first, replace_with),
        rest,
        list.append(indices, [index_range]),
      )
    }
  }
}

fn parse_digits_into_ranges(input: String) -> List(List(#(Int, Int, Int))) {
  let assert Ok(rex_digit) = regex.from_string("(\\d+)")

  input
  |> string.split("\n")
  |> list.map(fn(line) {
    regex.scan(rex_digit, line)
    |> list.flat_map(fn(rex) {
      case rex {
        regex.Match(_, s) ->
          s
          |> list.map(fn(m) {
            case m {
              option.Some(s) -> Ok(s)
              _ -> Error(Nil)
            }
          })
      }
    })
    |> result.values
    |> get_indicies_from_line(line, _, [])
  })
}

pub fn pt_1(input: String) {
  input
  |> string.split("\n")
  |> list.index_map(map_lines_to_coord_set)
  |> select_adjacent_symbols
  |> fn(adjacent_symbols) {
    // ok so now we have a list of symbols that are near numbers. 
    // now we parse all numbers and filter by those that are in range of symbols

    let digit_ranges = parse_digits_into_ranges(input)

    adjacent_symbols
    |> list.flat_map(fn(symbol) {
      select_digits_from_symbol(symbol, digit_ranges)
    })
    |> dict.from_list
    |> dict.values
    |> int.sum
  }
}

pub fn pt_2(input: String) {
  input
  |> string.split("\n")
  |> list.index_map(map_lines_to_coord_set)
  |> select_adjacent_symbols
  |> list.filter(fn(x) {
    case x {
      #(_, _, Symbol("*")) -> True
      _ -> False
    }
  })
  |> fn(adjacent_symbols) {
    let digit_ranges = parse_digits_into_ranges(input)

    adjacent_symbols
    |> list.map(fn(symbol) { select_digits_from_symbol(symbol, digit_ranges) })
    |> list.filter(fn(x) { list.length(x) == 2 })
    |> list.map(fn(x) {
      case x {
        [left, right] -> left.1 * right.1
        _ -> -999_999
      }
    })
    |> int.sum
  }
}
