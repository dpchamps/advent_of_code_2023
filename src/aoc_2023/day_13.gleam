import gleam/int
import gleam/list
import gleam/string
import common
import gleam/io
import gleam/dict
import gleam/set
import gleam/pair
import gleam/iterator
import gleam/result
import gleam/regex
import gleam/option
import gleam/float

fn verify_reflection(lhs: List(List(String)), rhs: List(List(String))) -> Bool {
  list.strict_zip(lhs, rhs)
  |> result.unwrap([#(["1"], ["2"])])
  |> list.all(fn(pair) { pair.0 == pair.1 })
}

fn float_to_int_ceil(input: Float) -> Int {
  float.ceiling(input)
  |> float.round
}

fn float_to_int_floor(input: Float) -> Int {
  float.floor(input)
  |> float.round
}

fn check_horizontal_reflection(
  input: List(List(String)),
  initial_length: Int,
  current_idx: Int,
  round_towards: fn(Float) -> Int,
) -> Result(Int, Nil) {
  case input {
    [head, ..tail] -> {
      case list.last(tail) {
        Ok(last) -> {
          // io.debug(#(head, last))
          case head == last {
            True -> {
              let inflection_point =
                int.to_float(current_idx) +. {
                  { int.to_float(initial_length) -. int.to_float(current_idx) } /. 2.0
                }
                |> round_towards
              let local_inflection =
                int.to_float(list.length(input)) /. 2.0
                |> round_towards

              let #(lhs, rhs) = list.split(input, local_inflection)

              case
                verify_reflection(
                  lhs,
                  rhs
                  |> list.reverse,
                )
              {
                False ->
                  check_horizontal_reflection(
                    tail,
                    initial_length,
                    current_idx + 1,
                    round_towards,
                  )
                True -> Ok(inflection_point)
              }
            }
            False ->
              check_horizontal_reflection(
                tail,
                initial_length,
                current_idx + 1,
                round_towards,
              )
          }
        }
        _ -> Error(Nil)
      }
    }
  }
}

fn parse_into_patterns(input: String) {
  input
  |> string.split("\n\n")
  |> list.map(common.parse_string_into_grid)
}

fn print_with_inflection_point(
  matrix: List(List(String)),
  inflection_point: Int,
) {
  let common.Coord(row_length, _) = common.two_d_array_dims(matrix)
  let header = common.array_with_length(row_length)
  io.debug(
    header
    |> list.map(int.to_string)
    |> fn(x) { #(x) },
  )
  matrix
  |> common.list_enumerate
  |> list.index_fold(
    [],
    fn(next, row, idx) {
      let next_row = case idx == inflection_point {
        True -> {
          io.debug(
            ">" <> {
              list.repeat("-", list.length(row.0) * 5)
              |> string.join("")
            } <> "<",
          )
          #("", 0)
        }
        False -> #("", 0)
      }

      // False -> list.append([" "], row)
      io.debug(row)
      next
    },
  )
}

fn max_result(x: Result(Int, a), y: Result(Int, a)) -> Result(Int, a) {
  case x, y {
    Ok(x), Ok(y) -> Ok(int.max(x, y))
    Ok(x), Error(_) -> Ok(x)
    Error(_), Ok(y) -> Ok(y)
    _, _ -> x
  }
}

fn get_reflections_for_pattern(pattern: List(List(String))) {
  let common.Coord(cols, rows) = common.two_d_array_dims(pattern)
  let horizontal_ref_top =
    check_horizontal_reflection(
      pattern
      |> list.reverse,
      rows,
      0,
      float_to_int_floor,
    )
    |> result.map(fn(idx) { rows - idx })

  let horizontal_ref_bottom =
    check_horizontal_reflection(pattern, rows, 0, float_to_int_ceil)

  let horizontal_ref = max_result(horizontal_ref_top, horizontal_ref_bottom)

  let rotated = common.rotate_matrix(pattern)

  let vertical_ref_top =
    check_horizontal_reflection(
      rotated
      |> list.reverse,
      cols,
      0,
      float_to_int_floor,
    )
    |> result.map(fn(idx) { cols - { idx } })

  let vertical_ref_bottom =
    check_horizontal_reflection(rotated, cols, 0, float_to_int_ceil)

  let vertical_ref = max_result(vertical_ref_top, vertical_ref_bottom)
  let result =
    {
      horizontal_ref
      |> result.map(fn(x) { #(x, 0) })
    }
    |> result.or(
      vertical_ref
      |> result.map(fn(x) { #(0, x) }),
    )

  result
}

fn add_part_one_computation(input: #(Int, Int)) -> Int {
  let #(hor_ref, vert_ref) = input
  hor_ref * 100 + vert_ref
}

fn two_lists_off_by_one(
  lists: #(#(List(String), Int), #(List(String), Int)),
) -> Bool {
  list.zip(pair.first(lists).0, pair.second(lists).0)
  |> list.filter(fn(x) { x.0 != x.1 })
  |> list.length
  |> fn(x) { x == 1 }
}

fn swap_in_smudge(
  pattern: List(List(String)),
  swap_with: #(#(List(String), Int), #(List(String), Int)),
) {
  common.list_swap_in_idx(
    pattern,
    pair.second(swap_with).0,
    pair.first(swap_with).1,
  )
}

fn find_and_fix_smudge_inner(
  pattern: List(List(String)),
) -> #(Result(#(Int, Int), Nil), Result(#(Int, Int), Nil)) {
  let original_reflection = get_reflections_for_pattern(pattern)
  // common.print_grid(pattern)
  // io.debug("_______________________________________")

  pattern
  |> common.list_enumerate
  |> list.combination_pairs
  // |> list.map(io.debug)
  |> list.flat_map(fn(p) { [p, pair.swap(p)] })
  |> list.filter(two_lists_off_by_one)
  // |> list.map(io.debug)
  |> list.map(swap_in_smudge(pattern, _))
  |> list.map(fn(swapped_pattern) {
    // io.debug("___")
    // common.print_grid(swapped_pattern)
    let reflection_point = get_reflections_for_pattern(swapped_pattern)

    reflection_point
  })
  |> list.filter(result.is_ok)
  |> common.list_dedup
  |> list.partition(fn(x) { x != original_reflection })
  |> fn(partitioned) {
    // io.debug(#("partitioned", partitioned))
    // choose
    case partitioned {
      #([choice], [original]) -> #(choice, original)
      #([choice], []) -> #(choice, Error(Nil))
      #([], [original]) -> #(Error(Nil), original)
      _ -> #(Error(Nil), Error(Nil))
    }
  }
}

fn find_and_fix_smudge(pattern: List(List(String))) -> #(Int, Int) {
  let common.Coord(col_length, row_length) = common.two_d_array_dims(pattern)
  io.debug("Checking horizontal")
  let #(maybe_horizontal_desmudge, maybe_horizontal_original) =
    find_and_fix_smudge_inner(pattern)
  io.debug("Checking vertical")
  let #(maybe_vertical_desmudge, maybe_vertical_original) =
    find_and_fix_smudge_inner(common.rotate_matrix(pattern))
    |> fn(x: #(Result(#(Int, Int), Nil), Result(#(Int, Int), Nil))) {
      #(
        x.0
        |> result.map(pair.swap),
        x.1
        |> result.map(pair.swap),
      )
    }

  //io.debug(#(maybe_horizontal_desmudge, maybe_vertical_desmudge))
  let assert Ok(desmugified) =
    maybe_horizontal_desmudge
    |> result.or(maybe_vertical_desmudge)
    |> result.or(maybe_horizontal_original)
    |> result.or(maybe_vertical_original)

  io.debug(#("result: ", desmugified))
  io.debug("_________________________")

  desmugified
}

pub fn pt_1(input: String) {
  input
  |> parse_into_patterns
  |> list.map(get_reflections_for_pattern)
  |> list.map(common.unwrap_panic)
  |> list.map(add_part_one_computation)
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> parse_into_patterns
  |> list.map(fn(x) {
    // common.print_grid(x)
    find_and_fix_smudge(x)
  })
  |> list.map(add_part_one_computation)
  // |> list.map(get_reflections_for_pattern)
  // |> list.map(add_part_one_computation)
  |> int.sum
}
