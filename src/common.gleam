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
