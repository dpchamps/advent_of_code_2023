import gleam/int
import gleam/list
import gleam/string
import common
import gleam/io
import gleam/set
import gleam/dict
import gleam/result
import direction
import priority_queue

type CoordState =
  #(common.Coord, direction.Direction, Int, List(common.Coord), Int)

fn compare_coord_state(a: CoordState, b: CoordState) {
  int.compare(a.2, b.2)
}

fn parse_input_into_board(input: String) -> List(List(Int)) {
  input
  |> string.split("\n")
  |> list.map(fn(line) {
    line
    |> string.split("")
    |> list.map(fn(x) {
      int.parse(x)
      |> common.unwrap_panic
    })
  })
}

fn select_next_directions(
  start: common.Coord,
  facing: direction.Direction,
  map: List(List(Int)),
  existing_heat_loss: Int,
  path: List(common.Coord),
  min_moves: Int,
  max_moves: Int,
) -> List(#(common.Coord, direction.Direction, Int, List(common.Coord), Int)) {
  common.array_with_length(max_moves - 1)
  |> list.fold(
    #(0, [], path),
    fn(state, steps) {
      let #(current_heat_loss, candidates, path) = state
      let distance = steps + 1
      let next_coord =
        direction.get_next_coord_from_direction(start, facing, distance)
      let next_path = [next_coord, ..path]

      case distance <= min_moves {
        True -> {
          let next_heat_loss = case common.list_at_coord(map, next_coord) {
            Ok(heat_loss) -> current_heat_loss + heat_loss
            Error(_) -> current_heat_loss
          }
          #(next_heat_loss, [], next_path)
        }
        _ -> {
          let turn_left = direction.ninty_degree_turn(facing, direction.Left)
          let turn_right = direction.ninty_degree_turn(facing, direction.Right)

          let #(next_heat_loss, result) = case
            common.list_at_coord(map, next_coord)
          {
            Ok(heat_loss) -> #(
              current_heat_loss + heat_loss,
              [
                Ok(#(
                  next_coord,
                  turn_left,
                  existing_heat_loss + current_heat_loss + heat_loss,
                  next_path,
                  distance,
                )),
                Ok(#(
                  next_coord,
                  turn_right,
                  existing_heat_loss + current_heat_loss + heat_loss,
                  next_path,
                  distance,
                )),
              ],
            )
            Error(_) -> #(current_heat_loss, [Error(Nil)])
          }

          #(next_heat_loss, list.append(result, candidates), next_path)
        }
      }
    },
  )
  |> fn(
    x: #(
      Int,
      List(
        Result(
          #(common.Coord, direction.Direction, Int, List(common.Coord), Int),
          Nil,
        ),
      ),
      List(common.Coord),
    ),
  ) {
    x.1
  }
  |> result.values
}

fn print_path(path: List(common.Coord), bounds: common.Coord) {
  let s = set.from_list(path)

  common.array_with_length(bounds.y)
  |> list.each(fn(y) {
    common.array_with_length(bounds.x)
    |> list.map(fn(x) {
      let c = common.Coord(x, y)
      case set.contains(s, c) {
        True -> "X"
        False -> "."
      }
    })
    |> string.join("")
    |> io.println
  })

  io.println("--")
}

fn find_shortest_path(
  map: List(List(Int)),
  queue: priority_queue.PriorityQueue(CoordState),
  c_e_tree: dict.Dict(common.Coord, Int),
  goal: common.Coord,
  checking: set.Set(#(common.Coord, direction.Direction, Int)),
  min_max_steps: common.Coord,
) {
  case priority_queue.dequeue(queue) {
    Ok(#(root, remaining_queue)) -> {
      let #(current_coord, current_direction, current_heat_cost, path, _) = root

      io.print(
        "Heating UP: " <> string.inspect(current_heat_cost) <> " " <> string.inspect(priority_queue.queue_size(
          remaining_queue,
        )) <> "\r",
      )

      let next_c_e_tree =
        common.upsert(
          c_e_tree,
          current_coord,
          common.max_safe_int,
          fn(existing_min) { int.min(current_heat_cost, existing_min) },
        ).0

      case current_coord == goal {
        True -> {
          let bounds = common.two_d_array_dims(map)
          io.println("")
          print_path(path, bounds)

          next_c_e_tree
        }
        False -> {
          let next_directions =
            select_next_directions(
              current_coord,
              current_direction,
              map,
              current_heat_cost,
              path,
              min_max_steps.x,
              min_max_steps.y,
            )
            |> list.filter(fn(x) {
              let #(next_coord, next_facing, _, _, dist) = x

              !set.contains(checking, #(next_coord, next_facing, dist))
            })

          let next_checking =
            list.fold(
              next_directions,
              checking,
              fn(checking_fold, el) {
                set.insert(checking_fold, #(el.0, el.1, el.4))
              },
            )

          let next_queue =
            priority_queue.add_list(remaining_queue, next_directions)

          find_shortest_path(
            map,
            next_queue,
            next_c_e_tree,
            goal,
            next_checking,
            min_max_steps,
          )
        }
      }
    }

    Error(_) -> c_e_tree
  }
}

fn find_best_lava_path(
  map: List(List(Int)),
  start: List(#(common.Coord, direction.Direction)),
  min_max_steps: common.Coord,
) -> Int {
  let bounds = common.two_d_array_dims(map)
  let start =
    list.map(start, fn(item) { #(item.0, item.1, 0, [], 0) })
    |> priority_queue.from_list(compare_coord_state)

  let result =
    find_shortest_path(map, start, dict.new(), bounds, set.new(), min_max_steps)

  dict.get(result, bounds)
  |> common.unwrap_panic
}

pub fn pt_1(input: String) {
  todo
  // todo
  // input
  // |> parse_input_into_board
  // |> find_best_lava_path(
  //   [
  //     #(common.Coord(0, 0), direction.East),
  //     #(common.Coord(0, 0), direction.South),
  //   ],
  //   common.Coord(0, 3),
  // )
}

pub fn pt_2(input: String) {
  input
  |> parse_input_into_board
  |> find_best_lava_path(
    [
      #(common.Coord(0, 0), direction.East),
      #(common.Coord(0, 0), direction.South),
    ],
    common.Coord(3, 10),
  )
}
