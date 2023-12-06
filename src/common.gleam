import gleam/dict
import gleam/result

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
