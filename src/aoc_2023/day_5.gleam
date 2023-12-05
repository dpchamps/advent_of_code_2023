import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/regex
import gleam/result
import gleam/option
import gleam/iterator

type MapKey =
  #(Int, Int, Int)

fn parse_seed_list(raw_input: List(String)) -> #(List(Int), List(String)) {
  let assert Ok(seed_matcher) = regex.from_string(".+: (.+)")

  case raw_input {
    [seed_list_raw, ..rest] -> {
      let seed_list =
        regex.scan(seed_matcher, seed_list_raw)
        |> list.flat_map(fn(match) {
          case match {
            regex.Match(_, [option.Some(digits)]) ->
              digits
              |> string.split(" ")
              |> list.map(fn(digit_str) {
                digit_str
                |> int.parse
              })
          }
        })
        |> result.values

      #(seed_list, rest)
    }
  }
}

fn list_into_pairs(l: List(Int)) {
  case l {
    [head, next, ..tail] -> [#(head, next), ..list_into_pairs(tail)]
    _ -> []
  }
}

fn parse_seeds_into_ranges(seeds: List(Int)) -> iterator.Iterator(Int) {
  seeds
  |> list_into_pairs
  |> io.debug
  |> list.sort(fn(a, b) { int.compare(a.0, b.0) })
  |> list.map(fn(range) { #(range.0, range.0 + range.1 - 1) })
  |> list.map(fn(range) { iterator.range(range.0, range.1) })
  |> iterator.from_list
  |> iterator.flatten
}

fn is_in_range(el, range: #(Int, Int)) -> Bool {
  el <= range.1 && el >= range.0
}

fn parse_maps(partial_input: #(List(Int), List(String))) {
  let #(seeds, rest) = partial_input
  let assert Ok(map_splitter) = regex.from_string(":\n((?:\n|.)+)")
  let assert Ok(range_splitter) = regex.from_string("(\\d+)")

  let maps =
    rest
    |> list.map(fn(el) {
      case regex.scan(map_splitter, el) {
        [regex.Match(_, [option.Some(digit_str)])] ->
          digit_str
          |> string.split("\n")
          |> list.map(fn(digit_line) {
            case regex.scan(range_splitter, digit_line) {
              [
                regex.Match(_, [option.Some(dest_start)]),
                regex.Match(_, [option.Some(src_start)]),
                regex.Match(_, [option.Some(length)]),
              ] -> {
                let assert Ok(dest_start) = int.parse(dest_start)
                let assert Ok(src_start) = int.parse(src_start)
                let assert Ok(length) = int.parse(length)

                #(dest_start, src_start, length)
              }
            }
          })
      }
    })

  #(seeds, maps)
}

fn map_value(key: List(MapKey), value: Int) {
  case
    key
    |> list.find(fn(el) {
      let #(dest, source, len) = el
      let source_range = #(source, source + len - 1)

      is_in_range(value, source_range)
    })
  {
    Ok(#(dest, source, range)) -> {
      let offset = value - source

      dest + offset
    }
    _ -> value
  }
}

fn input_to_raw(input: String) {
  input
  |> string.split("\n\n")
  |> parse_seed_list
}

fn run_seed_pipeline(x: #(List(Int), List(List(MapKey)))) {
  let #(seeds, maps) = x

  seeds
  |> list.map(fn(seed) {
    maps
    |> list.fold(
      seed,
      fn(value, map) {
        let mapped = map_value(map, value)

        mapped
      },
    )
  })
}

fn run_seed_iterator_pipeline(x: #(iterator.Iterator(Int), List(List(MapKey)))) {
  let #(seeds, maps) = x

  seeds
  |> iterator.map(fn(seed) {
    maps
    |> list.fold(
      seed,
      fn(value, map) {
        let mapped = map_value(map, value)

        mapped
      },
    )
  })
}

pub fn pt_1(input: String) {
  input
  |> input_to_raw
  |> parse_maps
  |> run_seed_pipeline
  |> list.fold(999_999_999_999_999, int.min)
}

pub fn pt_2(input: String) {
  input
  |> input_to_raw
  |> parse_maps
  |> fn(x: #(List(Int), List(List(MapKey)))) {
    let ranges = parse_seeds_into_ranges(x.0)
    #(ranges, x.1)
  }
  |> run_seed_iterator_pipeline
  |> iterator.fold(999_999_999_999_999, int.min)
}
