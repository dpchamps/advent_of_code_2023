import gleam/set

pub fn bfs(
  stack: List(a),
  visited: set.Set(a),
  state: b,
  on_step: fn(List(a), a, b) -> #(List(a), b),
) {
  case stack {
    [head, ..tail] -> {
      case
        visited
        |> set.contains(head)
      {
        True -> bfs(tail, visited, state, on_step)
        False -> {
          let updated_visited =
            visited
            |> set.insert(head)

          let #(updated_stack, updated_state) = on_step(stack, head, state)

          bfs(updated_stack, updated_visited, updated_state, on_step)
        }
      }
    }
    [] -> state
  }
}
