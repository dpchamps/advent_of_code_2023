import gleam/int
import gleam/list
import gleam/string
import common
import gleam/io
import gleam/pair
import gleam/iterator
import gleam/result
import gleam/regex
import gleam/option
import gleam/dict

pub type TextPos {
  TextPos(col: Int, length: Int)
}

pub type HotSpring {
  Operational(TextPos)
  Damaged(TextPos)
  PlaceHolder(TextPos)
}

pub type HotSpringLineUp =
  #(List(HotSpring), List(Int))

fn hotspring_of_char(char: String, index: Int, length: Int) -> HotSpring {
  case char {
    "." -> Operational(TextPos(index, length))
    "#" -> Damaged(TextPos(index, length))
    "?" -> PlaceHolder(TextPos(index, length))
  }
}

fn hotspring_line_to_string(x: List(HotSpring)) -> String {
  x
  |> list.map(char_of_hotspring)
  |> string.join("")
}

fn char_of_hotspring(hotspring: HotSpring) -> String {
  case hotspring {
    Operational(TextPos(_, length)) -> "."
    Damaged(TextPos(_, length)) -> "#"
    PlaceHolder(TextPos(_, length)) -> "?"
  }
}

fn hotspring_length(hotspring: HotSpring) -> Int {
  case hotspring {
    Operational(TextPos(_, length)) -> length
    Damaged(TextPos(_, length)) -> length
    PlaceHolder(TextPos(_, length)) -> length
  }
}

fn add_length_to_hotspring(input: HotSpring, n: Int) -> HotSpring {
  case input {
    Operational(TextPos(col, length)) -> Operational(TextPos(col, length + n))
    Damaged(TextPos(col, length)) -> Damaged(TextPos(col, length + n))
    PlaceHolder(TextPos(col, length)) -> PlaceHolder(TextPos(col, length + n))
  }
}

fn char_is_hotspring(char: String, hotspring: HotSpring) -> Bool {
  case hotspring {
    Operational(_) if char == "." -> True
    Damaged(_) if char == "#" -> True
    PlaceHolder(_) if char == "?" -> True
    _ -> False
  }
}

fn parse_single_hotspring(
  current: HotSpring,
  input: List(String),
  index: Int,
) -> #(HotSpring, List(String), Int) {
  case input {
    [head, ..tail] -> {
      case char_is_hotspring(head, current) {
        True ->
          parse_single_hotspring(
            add_length_to_hotspring(current, 1),
            tail,
            index + 1,
          )
        False -> #(current, input, index)
      }
    }
    [] -> #(current, [], index)
  }
}

fn parse_line_into_hotspring(input: List(String), index: Int) -> List(HotSpring) {
  case input {
    [head, ..tail] -> {
      let spring = hotspring_of_char(head, index, 1)
      // let #(spring, input, index) =
      //   parse_single_hotspring(spring, tail, index + 1)

      [spring, ..parse_line_into_hotspring(tail, index + 1)]
    }
    [] -> []
  }
}

fn parse_contiguous_groups(input: String) -> List(Int) {
  input
  |> string.split(",")
  |> list.map(int.parse)
  |> list.map(common.unwrap_panic)
}

fn parse_top_level_input(input: String) -> List(#(List(HotSpring), List(Int))) {
  input
  |> string.split("\n")
  |> list.map(fn(line) {
    case
      line
      |> string.split(" ")
    {
      [lhs, rhs] -> #(
        parse_line_into_hotspring(
          lhs
          |> string.to_graphemes,
          0,
        ),
        parse_contiguous_groups(rhs),
      )
      [] -> panic
    }
  })
}

fn unfold_input(input: HotSpringLineUp) -> HotSpringLineUp {
  #(
    input.0
    |> list.repeat(5)
    |> list.map(fn(x) { list.append(x, [PlaceHolder(TextPos(0, 0))]) })
    |> list.flatten,
    input.1
    |> list.repeat(5)
    |> list.flatten,
  )
}

fn is_placeholder(hotspring: HotSpring) -> Bool {
  char_of_hotspring(hotspring) == "?"
}

fn is_damaged(hotspring: HotSpring) -> Bool {
  char_of_hotspring(hotspring) == "#"
}

fn lineup_choose_two(
  hotspring: List(HotSpring),
) -> #(List(HotSpring), List(HotSpring)) {
  hotspring
  |> list.fold(
    #(#([], []), False),
    fn(state, el) {
      let #(#(left, right), found) = state
      case found {
        True -> #(#(list.append(left, [el]), list.append(right, [el])), True)
        False -> {
          case is_placeholder(el) {
            True -> #(
              #(
                list.append(left, [hotspring_of_char(".", 0, 0)]),
                list.append(right, [hotspring_of_char("#", 0, 0)]),
              ),
              True,
            )

            False -> #(
              #(list.append(left, [el]), list.append(right, [el])),
              False,
            )
          }
        }
      }
    },
  )
  |> pair.first
}

fn keep_lineup(lineup: HotSpringLineUp) -> Bool {
  // conditions where a lineup can be thrown away:
  // 1. there are more contiguous broken springs then there are parity bits
  //  1b. there are equal contiguous broken hot springs, but have a misalignment
  // 2. there are not enough contiguous areas to fill
  //    needs to account for the possibility that unknowns can be broken apart

  let #(hotsprings, parity_bits) = lineup
  let n_parity = list.length(parity_bits)
  // solving part 1
  let distint_possible_broken =
    list.length(
      list.chunk(hotsprings, fn(x) { is_damaged(x) || is_placeholder(x) })
      |> list.filter(fn(chunk) { !list.all(chunk, is_placeholder) }),
    ) <= n_parity

  // solving part 1.b
  let distinct_known_broken_contiguous = case
    common.list_split_on(hotsprings, is_placeholder)
  {
    #(lhs, _, option.Some(_)) ->
      list.chunk(lhs, is_damaged)
      |> list.map(list.length)
      |> list.zip(parity_bits)
      |> list.all(fn(pair) { pair.0 == pair.1 })
    _ -> True
  }

  // solving part 2
  let enough_contiguous_areas = {
    let x =
      list.chunk(hotsprings, fn(x) { is_damaged(x) || is_placeholder(x) })
      |> list.fold(
        [],
        fn(arr, chunk) {
          case chunk {
            [PlaceHolder(_), Damaged(_), ..] ->
              list.append(
                arr,
                [[PlaceHolder(TextPos(0, 0)), Damaged(TextPos(0, 0))]],
              )
          }
        },
      )
    list.length([]) >= n_parity

    True
  }

  distint_possible_broken && distinct_known_broken_contiguous && enough_contiguous_areas
}

fn lineup_choose_maybe_two(
  hotspring_lineup: HotSpringLineUp,
) -> List(List(HotSpring)) {
  hotspring_lineup.0
  |> lineup_choose_two
  |> common.list_of_pair
  |> list.filter(fn(hotspring) {
    // is_possible_partial_lineup(#(hotspring, hotspring_lineup.1))
    keep_lineup(#(hotspring, hotspring_lineup.1))
  })
}

fn search(
  grouped: List(List(HotSpring)),
  len: Int,
) -> Result(List(List(HotSpring)), Nil) {
  case grouped {
    [[Damaged(_), ..tail], ..rest] -> {
      case list.length(tail) + 1 == len {
        True -> Ok(rest)
        False -> Error(Nil)
      }
    }
    [_, ..tail] -> search(tail, len)
    [] -> Error(Nil)
  }
}

fn solve_potential_lineup(
  lineup: HotSpringLineUp,
  solved_bits: List(Int),
) -> List(Int) {
  let #(hotsprings, parity_bits) = lineup

  case parity_bits {
    [] -> solved_bits
    [bit, ..rest_bits] -> {
      // io.println(
      //   "\t\t" <> string.inspect(#(
      //     solved_bits,
      //     hotspring_line_to_string(hotsprings),
      //     bit,
      //   )),
      // )
      case list.split(hotsprings, bit) {
        #([Operational(_), ..rest], tail) ->
          // list.Continue(#(solved_bits, list.append(rest, tail)))
          solve_potential_lineup(
            #(list.append(rest, tail), parity_bits),
            solved_bits,
          )
        #(matched, remainder) -> {
          // io.println(
          //   "\t\t\t" <> string.inspect(#(
          //     hotspring_line_to_string(matched),
          //     "|",
          //     hotspring_line_to_string(remainder),
          //   )),
          // )
          // case list.all(matched, fn(x) { is_damaged(x) || is_placeholder(x) }) {
          //   False -> solved_bits
          //   True -> {
          let all_placeholders = list.all(matched, fn(x) { is_placeholder(x) })
          let all_damaged = list.all(matched, fn(x) { is_damaged(x) })

          let immediate =
            list.at(remainder, 0)
            |> result.unwrap(Operational(TextPos(0, 0)))

          case immediate {
            Damaged(_) if all_damaged == False -> {
              // note, we're solving it right now. 
              // what we're popping off right here must be operational 
              // Come back and do this
              let assert Ok(#(_, next_hotsprings)) =
                common.list_pop_top(hotsprings)
              solve_potential_lineup(
                #(next_hotsprings, parity_bits),
                solved_bits,
              )
            }
            // Damaged(_) if all_damaged -> solved_bits
            PlaceHolder(_) -> {
              // likewise here as well. This immediate must be operational
              // what we're popping off right here must be operational 
              // Come back and do this
              let #(_, next_remainder) =
                common.list_pop_top(remainder)
                |> result.unwrap(#(Operational(TextPos(0, 0)), []))
              // list.Continue(#(list.append(solved_bits, [bit]), remainder))
              solve_potential_lineup(
                #(next_remainder, rest_bits),
                list.append(solved_bits, [bit]),
              )
            }
            _ ->
              // list.Continue(#(list.append(solved_bits, [bit]), remainder))
              solve_potential_lineup(
                #(remainder, rest_bits),
                list.append(solved_bits, [bit]),
              )
          }
        }
      }
    }
  }
  //   }
  // }
}

fn evaluate_potential_lineup(lineup: HotSpringLineUp) -> Bool {
  let #(hotsprings, parity_bits) = lineup
  // io.debug(
  //   hotsprings
  //   |> hotspring_line_to_string,
  // )

  let chunked =
    list.chunk(lineup.0, fn(x) { is_damaged(x) || is_placeholder(x) })
  let distinct_placeholder =
    list.filter(
      chunked,
      fn(x) {
        case x {
          [Operational(_), ..] -> False
          _ -> True
        }
      },
    )

  let distinct_damaged =
    list.filter(
      chunked,
      fn(x) {
        case x {
          [Damaged(_), ..] -> True
          _ -> False
        }
      },
    )
  let d_length = list.length(chunked)
  let p_length = list.length(distinct_placeholder)
  let parity_length = list.length(parity_bits)
  let result = d_length > parity_length

  case result {
    False -> {
      io.debug(#(
        "Throwing away",
        hotspring_line_to_string(lineup.0),
        "Damaged: ",
        distinct_damaged
        |> list.map(hotspring_line_to_string),
        "Placeholder: ",
        distinct_placeholder
        |> list.map(hotspring_line_to_string),
        lineup.1,
      ))
    }
    True -> #("", "lineup", "", [], "", [], [])
  }

  result
  // io.println(
  //   "\t" <> string.inspect(#("Evaluating", hotspring_line_to_string(hotsprings))),
  // )
  // let result = solve_potential_lineup(lineup, [])
  // io.println(
  //   "\t" <> string.inspect(#(
  //     hotspring_line_to_string(hotsprings),
  //     "->",
  //     result,
  //     list.length(result) == list.length(parity_bits),
  //   )),
  // )

  // list.length(result) == list.length(parity_bits)
}

fn is_possible_lineup(lineup: HotSpringLineUp) -> Bool {
  let #(hotsprings, contiguous_chunks) = lineup
  let damaged_groups =
    hotsprings
    |> list.chunk(fn(x) {
      x
      |> char_of_hotspring
    })
    |> list.filter(fn(x) {
      case x {
        [Damaged(_), ..] -> True
        _ -> False
      }
    })
  list.length(damaged_groups) == list.length(contiguous_chunks) && list.zip(
    damaged_groups,
    contiguous_chunks,
  )
  |> list.all(fn(pair) { list.length(pair.0) == pair.1 })
}

fn is_possible_partial_lineup(lineup: HotSpringLineUp) -> Bool {
  // io.debug(#("Start", hotspring_line_to_string(lineup.0)))
  let #(hotsprings, contiguous_chunks) = lineup
  let damaged_and_placeholder_groups =
    list.chunk(
      hotsprings,
      fn(x) {
        x
        |> char_of_hotspring
      },
    )
    |> list.filter(fn(x) {
      case x {
        [Damaged(_), ..] | [PlaceHolder(_), ..] -> True
        _ -> False
      }
    })

  damaged_and_placeholder_groups
  |> list.fold_until(
    #(damaged_and_placeholder_groups, contiguous_chunks, True),
    fn(state, group) {
      let #(next_group, parity_bits, is_possible) = state
      // io.debug(#("Entry", next_group, parity_bits, is_possible))
      case parity_bits {
        [] -> list.Stop(state)
        [next_bit, ..remaining_bits] -> {
          case next_group {
            [[Damaged(_), ..tail], ..remaining_groups] -> {
              let match_len = list.length(tail) + 1
              let next_group_len =
                list.at(remaining_groups, 0)
                |> result.unwrap([])
                |> list.length
              // io.debug(#(
              //   "Damage Match",
              //   match_len,
              //   next_group_len,
              //   next_bit,
              //   match_len == next_bit || { next_bit - match_len } < next_group_len,
              // ))
              case
                match_len == next_bit || {
                  match_len < next_bit && { next_bit - match_len } < next_group_len
                }
              {
                False -> list.Stop(#(remaining_groups, parity_bits, False))
                True -> list.Continue(#(remaining_groups, remaining_bits, True))
              }
            }
            [_, ..tail] -> list.Continue(#(tail, remaining_bits, True))
          }
        }
      }
    },
  )
  // [placeholder_group, ..remaining_groups] -> {
  //   io.debug(remaining_groups)
  //   case list.split(placeholder_group, next_bit + 1) {
  //     #(to_take, to_put_back_on) -> {
  //       // io.debug(#(to_take, to_put_back_on))
  //       let next_group_len =
  //         list.at(remaining_groups, 0)
  //         // |> io.debug
  //         |> result.unwrap([])
  //         |> list.length
  //       let next_groups = case list.length(to_put_back_on) > 0 {
  //         True ->
  //           [to_put_back_on]
  //           |> list.append(remaining_groups)
  //         False -> remaining_groups
  //       }
  //       io.debug(#(
  //         "Placeholder match",
  //         list.length(to_take),
  //         next_group_len,
  //       ))
  //       case { list.length(to_take) + next_group_len } >= next_bit {
  //         True -> list.Continue(#(next_groups, remaining_bits, True))
  //         False -> list.Stop(#(next_groups, remaining_bits, False))
  //       }
  //     }
  //   }
  // }
  // |> fn(x: #(List(List(HotSpring)), List(Int), Bool)) {
  //   io.debug(#(
  //     "Result",
  //     x.2,
  //     x.2 && list.is_empty(x.1),
  //     x.1,
  //     lineup.0
  //     |> hotspring_line_to_string,
  //   ))
  //   x
  // }
  |> fn(x: #(List(List(HotSpring)), List(Int), Bool)) {
    x.2 && list.is_empty(x.1)
  }
  // io.debug(#(damaged_and_placeholder_groups, contiguous_chunks))
  // True
}

fn solve_line_up(lineup: HotSpringLineUp) -> Int {
  // io.debug(#(
  //   "Solving",
  //   lineup.0
  //   |> hotspring_line_to_string,
  //   lineup.1,
  // ))
  let #(hotsprings, contiguous_chunks) = lineup

  case
    hotsprings
    |> list.all(fn(x) { !is_placeholder(x) })
  {
    True ->
      case is_possible_lineup(lineup) {
        True -> {
          1
        }
        False -> 0
      }
    False -> {
      // let lineup_split = break_down_lineup(lineup)
      // io.debug(
      //   hotsprings
      //   |> hotspring_line_to_string,
      // )
      // io.debug(#(
      //   lineup_split.0
      //   |> hotspring_line_to_string,
      //   lineup_split.1,
      // ))
      let result =
        lineup_choose_maybe_two(lineup)
        |> list.map(fn(x) { solve_line_up(#(x, contiguous_chunks)) })
        |> int.sum

      // let #(next_left, next_right) = lineup_choose_two(hotsprings)
      // is_possible_partial_lineup(#(next_left, contiguous_chunks))
      // let result =
      //   solve_line_up(#(next_left, contiguous_chunks)) + solve_line_up(#(
      //     next_right,
      //     contiguous_chunks,
      //   ))

      result
    }
  }
}

fn solve_line_slow(lineup: HotSpringLineUp) -> Int {
  let #(hotsprings, contiguous_chunks) = lineup

  case
    hotsprings
    |> list.all(fn(x) { !is_placeholder(x) })
  {
    True ->
      case is_possible_lineup(lineup) {
        True -> {
          1
        }
        False -> 0
      }
    False -> {
      let #(next_left, next_right) = lineup_choose_two(hotsprings)
      is_possible_partial_lineup(#(next_left, contiguous_chunks))
      let result =
        solve_line_slow(#(next_left, contiguous_chunks)) + solve_line_slow(#(
          next_right,
          contiguous_chunks,
        ))

      result
    }
  }
}

fn solve_line_up_with_cache(
  lineup: HotSpringLineUp,
  cache: dict.Dict(String, Int),
) -> #(Int, dict.Dict(String, Int)) {
  let #(hotsprings, contiguous_chunks) = lineup
  let cache_key = hotspring_line_to_string(hotsprings)
  case dict.get(cache, cache_key) {
    Ok(value) -> #(value, cache)
    _ -> {
      case
        hotsprings
        |> list.all(fn(x) { !is_placeholder(x) })
      {
        True ->
          case is_possible_lineup(lineup) {
            True -> {
              #(1, dict.insert(cache, cache_key, 1))
            }
            False -> #(0, dict.insert(cache, cache_key, 1))
          }
        False -> {
          let #(next_left, next_right) = lineup_choose_two(hotsprings)
          let #(lineup_left_result, _) =
            solve_line_up_with_cache(#(next_left, contiguous_chunks), cache)
          let #(lineup_right_result, _) =
            solve_line_up_with_cache(#(next_right, contiguous_chunks), cache)

          let result = lineup_left_result + lineup_right_result
          let next_cache = dict.insert(cache, cache_key, result)
          #(result, next_cache)
        }
      }
    }
  }
}

fn solve_line_cache(lineup: HotSpringLineUp) -> Int {
  solve_line_up_with_cache(lineup, dict.new())
  |> pair.first
}

fn solve_lineup_cached(lineups: List(HotSpringLineUp)) -> Int {
  lineups
  |> list.fold(
    #(0, dict.new()),
    fn(state, lineup) {
      let #(total, cache) = state
      let #(solutions, next_cache) = solve_line_up_with_cache(lineup, cache)

      #(total + solutions, next_cache)
    },
  )
  |> pair.first
}

pub fn pt_1(input: String) {
  input
  |> parse_top_level_input
  // |> solve_lineup_cached
  |> list.map(solve_line_cache)
  |> int.sum
}

pub fn pt_2(input: String) {
  todo
  // todo
  // input
  // |> parse_top_level_input
  // |> list.map(unfold_input)
  // |> list.map(solve_line_cache)
  // |> int.sum
  // |> list.index_map(fn(idx, x) {
  //   // io.debug("-----------------------------")
  //   let result = solve_line_up(x)
  //   // let result = solve_line_slow(x)
  //   io.debug(#(
  //     x.0
  //     |> hotspring_line_to_string,
  //     x.1,
  //   ))
  //   io.println(string.inspect(#("Total Count: ", result, "Idx: ", idx)))
  //   // "Compare: ",
  //   // compare,
  //   // case result != compare {
  //   //   True -> {
  //   //     io.println(hotspring_line_to_string(x.0))
  //   //     panic
  //   //   }
  //   //   False -> #()
  //   // }
  //   result
  // })
  // // |> list.each(io.debug)
  // |> int.sum
}
