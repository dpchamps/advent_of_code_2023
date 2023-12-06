import gleam/int
import gleam/list
import gleam/string
import gleam/regex
import gleam/result
import gleam/option
import common
import gleam/pair

type MapKey =
  #(Int, Int, Int)

type Range =
  #(Int, Int)

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

fn intersection_of_keys(keys: List(MapKey), range: Range) -> List(Range) {
  keys
  |> of_range_list
  |> list.map(pair.first)
  |> list.filter(fn(x) {
    x
    |> range_intersects(range)
  })
}

fn sort_range_ascending(a: Range, b: Range) {
  int.compare(a.0, b.0)
}

fn range_into_subsets(step: #(Range, List(Range)), part: Range) {
  let #(last_range, parts) = step
  case int.min(last_range.0, part.0) {
    n if n == last_range.0 && n != part.0 -> #(
      #(part.1 + 1, last_range.1),
      [#(last_range.0, part.0 - 1), part, ..parts],
    )
    _ -> #(#(part.1 + 1, last_range.1), [part, ..parts])
  }
}

fn map_source_range_to_dest_range(known_range: Range, keys: List(MapKey)) {
  // now that we have a list of known inclusive ranges, we map them into destination ranges.
  // Either the range fits into a source range, for which we resolve to the full destination range
  // or we resolve to the input range
  case
    keys
    |> list.find(fn(mapped_range) {
      range_contains(
        mapped_range
        |> of_range
        |> pair.first,
        known_range,
      )
    })
  {
    Ok(found_key) -> {
      let #(source, destination) =
        found_key
        |> of_range

      let input_len = known_range.1 - known_range.0
      let range_start_offset = known_range.0 - source.0
      let mapped_destination = #(
        destination.0 + range_start_offset,
        destination.0 + range_start_offset + input_len,
      )

      mapped_destination
    }
    _ -> known_range
  }
}

fn map_group(keys: List(MapKey), range: Range) {
  range
  // If the key does not intersect with the range, remove it as a candidate
  case intersection_of_keys(keys, range) {
    [] -> {
      [range]
    }
    intersection -> {
      // sort keys by start ascending, to make splitting easier later
      intersection
      |> list.sort(sort_range_ascending)
      |> list.map(fn(key_range) {
        // cases: 
        // the key is a subset of the range, for which we take the full key_range
        // the key is an intersection of the range, take the intersection
        case range_contains(range, key_range) {
          True -> key_range
          _ -> range_intersection(range, key_range)
        }
      })
      // We're going to cut the range into pieces: parts that are in the maps keys, and parts that are out
      // At this point we have parts of the initial range, we need to now split the initial range into 
      // these parts + anything that is missing
      |> list.fold(#(range, []), range_into_subsets)
      |> pair.second
      |> list.map(fn(known_range) {
        map_source_range_to_dest_range(known_range, keys)
      })
    }
  }
}

fn resolve_ranges(maps: List(List(MapKey)), ranges: List(#(Int, Int))) {
  case maps {
    [map, ..tail] -> {
      let next_ranges =
        ranges
        |> list.flat_map(fn(range) { map_group(map, range) })

      resolve_ranges(tail, next_ranges)
    }
    _ -> ranges
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

fn range_intersects(range_one: #(Int, Int), range_two: #(Int, Int)) -> Bool {
  { range_two.1 >= range_one.0 && range_two.0 <= range_one.1 }
}

fn range_contains(source: #(Int, Int), other: #(Int, Int)) -> Bool {
  source.0 <= other.0 && source.1 >= other.1
}

fn range_intersection(source: #(Int, Int), target: #(Int, Int)) -> #(Int, Int) {
  #(int.max(source.0, target.0), int.min(source.1, target.1))
}

fn of_range(key: MapKey) {
  let #(dest, source, len) = key
  let source_range = #(source, source + len - 1)
  let dest_range = #(dest, dest + len - 1)

  #(source_range, dest_range)
}

fn of_range_list(keys: List(MapKey)) {
  keys
  |> list.map(of_range)
}

pub fn pt_1(input: String) {
  input
  |> input_to_raw
  |> parse_maps
  |> run_seed_pipeline
  |> list.fold(common.max_safe_int, int.min)
}

pub fn pt_2(input: String) {
  input
  |> input_to_raw
  |> parse_maps
  |> fn(x: #(List(Int), List(List(MapKey)))) {
    let #(seeds, maps) = x

    let seed_ranges =
      seeds
      |> list_into_pairs
      |> list.map(fn(range) { #(range.0, range.0 + range.1 - 1) })

    resolve_ranges(maps, seed_ranges)
  }
  |> list.fold(
    common.max_safe_int,
    fn(smallest, range) {
      // we're left with locations, we now need to take the smallest LHS
      int.min(smallest, range.0)
    },
  )
}
