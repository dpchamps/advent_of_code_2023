import gleam/dict
import gleam/result
import gleam/list
import gleam/option
import gleam/set
import gleam/string
import gleam/iterator
import gleam/io
import gleam/int

pub fn upsert(d: dict.Dict(a, b), at: a, default: b, update_with: fn(b) -> b) {
  d
  |> dict.get(at)
  |> result.unwrap(default)
  |> update_with
  |> fn(res) {
    #(
      d
      |> dict.insert(at, res),
      res,
    )
  }
}

pub fn update(
  d: dict.Dict(a, b),
  at: a,
  update_fn: fn(b) -> b,
) -> Result(dict.Dict(a, b), Nil) {
  d
  |> dict.get(at)
  |> result.map(fn(v) { dict.insert(d, at, update_fn(v)) })
}

pub fn dict_entries(d: dict.Dict(a, b)) -> List(#(a, b)) {
  d
  |> dict.keys
  |> list.zip(
    d
    |> dict.values,
  )
}

pub const max_safe_int = 9_007_199_254_740_991

pub fn identity(x: a) -> a {
  x
}

pub fn unwrap_panic(x: Result(a, b)) -> a {
  case x {
    Ok(r) -> r
    _ -> panic
  }
}

pub fn unwrap_expect(x: Result(a, b), message: String) -> a {
  case x {
    Ok(r) -> r
    _ ->
      io.debug(message)
      |> panic
  }
}

pub fn pair_of_list(l: List(a)) -> Result(#(a, a), Nil) {
  case l {
    [first, second] -> Ok(#(first, second))
    _ -> Error(Nil)
  }
}

pub fn list_into_pairs(l: List(a)) {
  case l {
    [head, next, ..tail] -> [#(head, next), ..list_into_pairs(tail)]
    _ -> []
  }
}

pub fn list_take_one(l: List(a), f: fn(a) -> Bool) {
  let reduced =
    l
    |> list.index_fold(
      #([], option.None),
      fn(acc, x, index) {
        let #(next_list, stop_searching) = acc
        case stop_searching {
          option.Some(i) -> #(
            next_list
            |> list.append([x]),
            option.Some(i),
          )
          _ -> {
            let ignore = f(x)
            case ignore {
              False -> #(
                next_list
                |> list.append([x]),
                option.None,
              )
              True -> #(next_list, option.Some(index))
            }
          }
        }
      },
    )

  case reduced.1 {
    option.Some(x) -> Ok(#(reduced.0, x))
    _ -> Error(Nil)
  }
}

pub fn list_insert_at(l: List(a), to_insert: a, idx: Int) -> List(a) {
  let list_len =
    l
    |> list.length

  case idx >= list_len {
    True ->
      l
      |> list.append([to_insert])
    False ->
      l
      |> list.index_fold(
        [],
        fn(acc, el, index) {
          case idx - index {
            0 ->
              acc
              |> list.append([to_insert, el])
            _ ->
              acc
              |> list.append([el])
          }
        },
      )
  }
}

pub fn list_swap_in_idx(l: List(a), el: a, idx: Int) -> List(a) {
  l
  |> list.index_fold(
    [],
    fn(arr, a_el, a_idx) {
      case idx == a_idx {
        True -> list.append(arr, [el])
        _ -> list.append(arr, [a_el])
      }
    },
  )
}

pub fn list_split_on(l: List(a), splitter: fn(a) -> Bool) {
  l
  |> list.fold(
    #([], [], option.None),
    fn(acc, el) {
      case acc.2 {
        option.None ->
          case splitter(el) {
            True -> #(acc.0, [], option.Some(el))
            False -> #(
              acc.0
              |> list.append([el]),
              [],
              option.None,
            )
          }
        _ -> #(
          acc.0,
          acc.1
          |> list.append([el]),
          acc.2,
        )
      }
    },
  )
}

/// Take all elements from set a that arent in set b
pub fn set_subtraction(s_a: set.Set(a), s_b: set.Set(a)) -> set.Set(a) {
  s_a
  |> set.to_list
  |> list.fold(
    set.new(),
    fn(acc, el) {
      case
        s_b
        |> set.contains(el)
      {
        True -> acc
        False ->
          acc
          |> set.insert(el)
      }
    },
  )
}

pub fn parse_string_into_grid(input: String) -> List(List(String)) {
  input
  |> string.split("\n")
  |> list.map(string.to_graphemes)
}

pub fn print_grid_of_strings(input: List(List(String))) {
  input
  |> list.each(fn(x) {
    x
    |> string.join("")
    |> io.println
  })
}

pub fn print_grid(input: List(List(String))) {
  input
  |> list_enumerate
  |> list.each(fn(x) {
    x
    |> io.debug
  })
}

pub fn array_with_length(len: Int) -> List(Int) {
  case len {
    0 -> [0]
    n ->
      array_with_length(len - 1)
      |> list.append([len])
  }
}

// pub fn array_with_length(len: Int) -> List(Int) {
//   case len {
//     0 -> [0]
//     n ->
//       array_with_length(len - 1)
//       |> list.append([len])
//   }
// }

pub type Coord {
  Coord(x: Int, y: Int)
}

pub fn two_d_array_dims(in: List(List(a))) -> Coord {
  Coord(
    in
    |> list.at(0)
    |> unwrap_panic
    |> list.length
    |> int.subtract(1),
    in
    |> list.length
    |> int.subtract(1),
  )
}

pub fn list_of_pair(x: #(a, a)) -> List(a) {
  [x.0, x.1]
}

pub fn list_pop_top(x: List(a)) -> Result(#(a, List(a)), Nil) {
  case x {
    [head, ..tail] -> Ok(#(head, tail))
    [] -> Error(Nil)
  }
}

pub fn list_pop_back(x: List(a)) -> Result(#(a, List(a)), Nil) {
  case list.split(x, list.length(x) - 1) {
    #(list, [el]) -> Ok(#(el, list))
    _ -> Error(Nil)
  }
}

pub fn rotate_matrix(input: List(List(a))) -> List(List(a)) {
  let Coord(rows, _) = two_d_array_dims(input)
  let base =
    array_with_length(rows)
    |> list.map(fn(_) { [] })
  input
  |> list.reverse
  |> list.fold(
    base,
    fn(rotated, row) {
      row
      // |> list.reverse
      |> list.index_fold(
        rotated,
        fn(acc, el, idx) {
          let r = case list.at(acc, idx) {
            Ok(arr) ->
              arr
              |> list.append([el])
            _ -> [el]
          }

          list_swap_in_idx(acc, r, idx)
        },
      )
    },
  )
}

pub fn list_enumerate(input: List(a)) -> List(#(a, Int)) {
  list.index_map(input, fn(i, x) { #(x, i) })
}

pub fn list_dedup(input: List(a)) -> List(a) {
  input
  |> set.from_list
  |> set.to_list
}

pub fn dict_two_d_array_into_map(input: List(List(a))) -> dict.Dict(Coord, a) {
  input
  |> list.index_fold(
    dict.new(),
    fn(map, row, y) {
      row
      |> list.index_fold(
        map,
        fn(map, el, x) { dict.insert(map, Coord(x, y), el) },
      )
    },
  )
}

pub fn list_at_coord(input: List(List(a)), coord: Coord) -> Result(a, Nil) {
  case list.at(input, coord.y) {
    Ok(row) -> list.at(row, coord.x)
    Error(_) -> Error(Nil)
  }
}

pub fn unreachable(message: String) {
  io.println_error("UNREACHABLE: " <> message)
  panic
}

pub fn dict_pretty_print(input: dict.Dict(a, b)) -> dict.Dict(a, b) {
  io.println("{")
  dict_entries(input)
  |> list.each(fn(entry) {
    io.println(
      "\t" <> string.inspect(entry.0) <> " : " <> string.inspect(entry.1),
    )
  })
  io.println("}")
  input
}
