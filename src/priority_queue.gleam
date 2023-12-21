import gleam/order
import gleam/int
import gleam/float
import gleam/result
import gleam/list

type CompareFn(a) =
  fn(a, a) -> order.Order

pub opaque type PriorityQueue(a) {
  Empty(compare: CompareFn(a))
  PriorityQueue(
    size: Int,
    height: Int,
    min: a,
    left: PriorityQueue(a),
    right: PriorityQueue(a),
    compare: CompareFn(a),
  )
}

pub fn new(compare: CompareFn(a)) -> PriorityQueue(a) {
  Empty(compare)
}

pub fn min_heap() -> PriorityQueue(Int) {
  new(int.compare)
}

pub fn max_heap() -> PriorityQueue(Int) {
  let cmp = fn(a: Int, b: Int) {
    int.compare(a, b)
    |> order.negate
  }
  new(cmp)
}

pub fn from_list(l: List(a), compare: CompareFn(a)) -> PriorityQueue(a) {
  l
  |> list.fold(new(compare), fn(q, el) { enqueue(q, el) })
}

pub fn to_list(q: PriorityQueue(a)) -> List(a) {
  case dequeue(q) {
    Ok(#(el, q)) -> [el, ..to_list(q)]
    Error(_) -> []
  }
}

pub fn add_list(q: PriorityQueue(a), l: List(a)) -> PriorityQueue(a) {
  l
  |> list.fold(q, fn(acc, el) { enqueue(acc, el) })
}

pub fn enqueue(q: PriorityQueue(a), el: a) -> PriorityQueue(a) {
  case q {
    Empty(compare) -> branch(el, Empty(compare), Empty(compare), compare)
    PriorityQueue(_, _, min, left, right, compare) -> {
      let left_size = queue_size(left)
      let right_size = queue_size(right)
      let left_height = queue_height(left)
      let right_height = queue_height(right)
      let left_size_compare = height_heuristic(left_height)
      let right_size_compare = height_heuristic(right_height)

      case #() {
        _ if left_size < left_size_compare ->
          bubble_up(min, enqueue(left, el), right, compare)
        _ if right_size < right_size_compare ->
          bubble_up(min, left, enqueue(right, el), compare)
        _ if right_height < left_height ->
          bubble_up(min, left, enqueue(right, el), compare)
        _ -> bubble_up(min, enqueue(left, el), right, compare)
      }
    }
  }
}

pub fn dequeue(q: PriorityQueue(a)) -> Result(#(a, PriorityQueue(a)), Nil) {
  case q {
    Empty(_) -> Error(Nil)
    PriorityQueue(_, _, min, left, right, _) -> {
      Ok(#(min, bubble_root_down(merge(left, right))))
    }
  }
}

fn bubble_up(
  x: a,
  left: PriorityQueue(a),
  right: PriorityQueue(a),
  compare: CompareFn(a),
) -> PriorityQueue(a) {
  compare_value_to_branch(x, left, compare)
  |> result.then(fn(l_comp) {
    let assert PriorityQueue(_, _, y, left_y, right_y, _) = left
    case l_comp {
      order.Gt ->
        Ok(branch(y, branch(x, left_y, right_y, compare), right, compare))
      _ -> Error(Nil)
    }
  })
  |> result.try_recover(fn(_) {
    compare_value_to_branch(x, right, compare)
    |> result.then(fn(r_comp) {
      let assert PriorityQueue(_, _, z, left_z, right_z, _) = right
      case r_comp {
        order.Gt ->
          Ok(branch(z, left, branch(x, left_z, right_z, compare), compare))
        _ -> Error(Nil)
      }
    })
  })
  |> result.lazy_unwrap(fn() { branch(x, left, right, compare) })
}

fn bubble_root_down(q: PriorityQueue(a)) -> PriorityQueue(a) {
  case q {
    Empty(compare) -> Empty(compare)
    PriorityQueue(_, _, x, left, right, compare) ->
      bubble_down(x, left, right, compare)
  }
}

fn bubble_down(
  x: a,
  left: PriorityQueue(a),
  right: PriorityQueue(a),
  compare: CompareFn(a),
) -> PriorityQueue(a) {
  result_join(
    compare_value_to_branch(x, right, compare),
    compare_values_in_branches(right, left, compare),
  )
  |> result.then(fn(comps) {
    let assert PriorityQueue(_, _, z, r_left, r_right, _) = right
    let #(z_comp, z_y_comp) = comps
    case z_comp, z_y_comp {
      order.Gt, order.Lt ->
        Ok(branch(z, left, bubble_down(x, r_left, r_right, compare), compare))
      _, _ -> Error(Nil)
    }
  })
  |> result.try_recover(fn(_) {
    compare_value_to_branch(x, left, compare)
    |> result.then(fn(y_comp) {
      let assert PriorityQueue(_, _, y, l_left, l_right, _) = left
      case y_comp {
        order.Gt ->
          Ok(branch(y, bubble_down(x, l_left, l_right, compare), right, compare))
        _ -> Error(Nil)
      }
    })
  })
  |> result.lazy_unwrap(fn() { branch(x, left, right, compare) })
}

pub fn queue_size(q: PriorityQueue(a)) -> Int {
  case q {
    Empty(_) -> 0
    PriorityQueue(size, _, _, _, _, _) -> size
  }
}

pub fn queue_height(q: PriorityQueue(a)) -> Int {
  case q {
    Empty(_) -> 0
    PriorityQueue(_, height, _, _, _, _) -> height
  }
}

fn branch(
  min: a,
  left: PriorityQueue(a),
  right: PriorityQueue(a),
  compare: CompareFn(a),
) -> PriorityQueue(a) {
  let size = queue_size(left) + queue_size(right) + 1
  let height = int.max(queue_size(left), queue_size(right)) + 1

  PriorityQueue(size, height, min, left, right, compare)
}

fn merge(left: PriorityQueue(a), right: PriorityQueue(a)) -> PriorityQueue(a) {
  let left_size = queue_size(left)
  let right_size = queue_size(right)
  let left_height = queue_height(left)
  let right_height = queue_height(right)
  let left_size_compare = height_heuristic(left_height)
  let right_size_compare = height_heuristic(right_height)

  case left, right {
    Empty(compare), Empty(_) -> Empty(compare)
    PriorityQueue(_, _, l_min, l_left, l_right, _), _ if left_size < left_size_compare ->
      float_left(l_min, merge(l_left, l_right), right)
    _, PriorityQueue(_, _, r_min, r_left, r_right, _) if right_size < right_size_compare ->
      float_right(r_min, left, merge(r_left, r_right))
    PriorityQueue(_, _, l_min, l_left, l_right, _), _ if right_height < left_height ->
      float_left(l_min, merge(l_left, l_right), right)
    _, PriorityQueue(_, _, r_min, r_left, r_right, _) ->
      float_right(r_min, left, merge(r_left, r_right))
  }
}

fn float_left(
  el: a,
  l: PriorityQueue(a),
  r: PriorityQueue(a),
) -> PriorityQueue(a) {
  case l {
    Empty(compare) -> branch(el, l, r, compare)
    PriorityQueue(_, _, y, l_left, l_right, compare) ->
      branch(y, branch(el, l_left, l_right, compare), r, compare)
  }
}

fn float_right(
  el: a,
  l: PriorityQueue(a),
  r: PriorityQueue(a),
) -> PriorityQueue(a) {
  case r {
    Empty(compare) -> branch(el, l, r, compare)
    PriorityQueue(_, _, y, r_left, r_right, compare) ->
      branch(y, l, branch(el, r_left, r_right, compare), compare)
  }
}

fn height_heuristic(height: Int) -> Int {
  let result =
    int.power(height, 2.0)
    |> result.unwrap(0.0)
    |> float.round
    |> int.subtract(1)

  result
}

fn compare_value_to_branch(
  x: a,
  branch: PriorityQueue(a),
  compare: CompareFn(a),
) -> Result(order.Order, Nil) {
  case branch {
    Empty(_) -> Error(Nil)
    PriorityQueue(_, _, val, _, _, _) -> Ok(compare(x, val))
  }
}

fn compare_values_in_branches(
  left: PriorityQueue(a),
  right: PriorityQueue(a),
  compare: CompareFn(a),
) -> Result(order.Order, Nil) {
  case left, right {
    PriorityQueue(_, _, left_val, _, _, _), PriorityQueue(
      _,
      _,
      right_val,
      _,
      _,
      _,
    ) -> {
      Ok(compare(left_val, right_val))
    }
    _, _ -> Error(Nil)
  }
}

fn result_join(a: Result(a, b), b: Result(a, b)) -> Result(#(a, a), b) {
  case a, b {
    Ok(a_val), Ok(b_val) -> Ok(#(a_val, b_val))
    Error(err), _ | _, Error(err) -> Error(err)
  }
}
