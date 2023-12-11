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

pub fn list_split_on(l: List(a), splitter: fn(a) -> Bool) {
  l
  |> list.fold(
    #([], [], option.None),
    fn(acc, el) {
      case acc.1 {
        [] ->
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

pub fn array_with_length(len: Int) -> List(Int) {
  case len {
    0 -> [0]
    n ->
      array_with_length(len - 1)
      |> list.append([len])
  }
}

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
