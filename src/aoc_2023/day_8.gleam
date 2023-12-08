import gleam/list
import gleam/string
import gleam/regex
import gleam/option
import gleam/iterator
import gleam/dict
import gleam_community/maths/arithmetics

type LeftRight =
  #(String, String)

type Map =
  dict.Dict(String, LeftRight)

type Sequence =
  iterator.Iterator(String)

fn parse_sequence(input: String) -> Sequence {
  input
  |> string.trim
  |> string.to_graphemes
  |> iterator.from_list
  |> iterator.cycle
}

fn parse_map(input: String) -> Map {
  let assert Ok(rex_key_parser) = regex.from_string("(.+) = \\((.+), (.+)\\)")

  input
  |> string.trim
  |> string.split("\n")
  |> list.fold(
    dict.new(),
    fn(map, line) {
      case
        rex_key_parser
        |> regex.scan(line)
      {
        [
          regex.Match(
            _,
            [option.Some(key), option.Some(left), option.Some(right)],
          ),
        ] -> {
          map
          |> dict.insert(key, #(left, right))
        }
        _ -> panic
      }
    },
  )
}

fn parse_input(input: String) -> #(Sequence, Map) {
  case
    input
    |> string.split_once("\n")
  {
    Ok(#(left, right)) -> {
      #(parse_sequence(left), parse_map(right))
    }
    _ -> panic
  }
}

fn run_selection_pipeline(input: #(Sequence, Map)) {
  let #(sequence, map) = input

  sequence
  |> iterator.fold_until(
    #(0, "AAA"),
    fn(acc, direction) {
      let #(n_moves, next_key) = acc

      let assert Ok(next_move) =
        map
        |> dict.get(next_key)

      case next_key {
        "ZZZ" -> {
          list.Stop(acc)
        }
        _ -> {
          let result = case direction {
            "L" -> #(n_moves + 1, next_move.0)

            "R" -> #(n_moves + 1, next_move.1)
          }

          list.Continue(result)
        }
      }
    },
  )
  |> fn(x: #(Int, String)) { x.0 }
}

fn run_selection_pipeline_two(input: #(Sequence, Map)) {
  let #(sequence, map) = input
  let start_keys =
    map
    |> dict.keys
    |> list.filter(fn(key) {
      key
      |> string.ends_with("A")
    })

  sequence
  |> iterator.fold_until(
    #(0, start_keys, []),
    fn(acc, direction) {
      let #(n_moves, next_keys, paths) = acc
      let next_n_moves = n_moves + 1
      let next_moves =
        next_keys
        |> list.map(fn(next_key) {
          let assert Ok(next_move) =
            map
            |> dict.get(next_key)
          case direction {
            "L" -> next_move.0
            "R" -> next_move.1
          }
        })

      let search_length =
        next_keys
        |> list.length
      case
        paths
        |> list.length
      {
        n if n == search_length -> {
          list.Stop(#(next_n_moves, next_moves, paths))
        }
        _ -> {
          let next_paths =
            paths
            |> list.append(
              next_moves
              |> list.filter(fn(x) {
                x
                |> string.ends_with("Z")
              })
              |> list.map(fn(_) { next_n_moves }),
            )
          list.Continue(#(next_n_moves, next_moves, next_paths))
        }
      }
    },
  )
  |> fn(x: #(Int, List(String), List(Int))) { x.2 }
  |> list.fold(1, fn(lcm, el) { arithmetics.lcm(lcm, el) })
}

pub fn pt_1(input: String) {
  input
  |> parse_input
  |> run_selection_pipeline
}

pub fn pt_2(input: String) {
  input
  |> parse_input
  |> run_selection_pipeline_two
}
