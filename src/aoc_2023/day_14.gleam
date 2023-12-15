import gleam/int
import gleam/list
import common
import gleam/io
import gleam/dict
import gleam/pair
import gleam/iterator

pub type Direction {
  North
  South
  East
  West
}

pub type BoardElement {
  RoundRock
  CubeRock
  EmptySpace
}

pub type Board =
  List(List(BoardElement))

fn board_el_of_string(char: String) -> BoardElement {
  case char {
    "#" -> CubeRock
    "O" -> RoundRock
    "." -> EmptySpace
  }
}

fn parse_row_into_board_element(input: List(String)) -> List(BoardElement) {
  input
  |> list.map(board_el_of_string)
}

fn parse_board(input: String) {
  input
  |> common.parse_string_into_grid
  |> list.map(parse_row_into_board_element)
}

fn two_d_array_into_dict(
  input: List(List(a)),
) -> #(dict.Dict(common.Coord, a), common.Coord) {
  let d =
    input
    |> list.index_fold(
      dict.new(),
      fn(map, row, row_idx) {
        row
        |> list.index_fold(
          map,
          fn(map, el, col_idx) {
            map
            |> dict.insert(common.Coord(col_idx, row_idx), el)
          },
        )
      },
    )

  let #(y, x) = bounds_from_dict(d)

  #(d, common.Coord(x, y))
}

fn bounds_from_dict(input: dict.Dict(common.Coord, a)) -> #(Int, Int) {
  input
  |> dict.keys
  |> list.fold(
    #(-1, -1),
    fn(acc, key) {
      let #(current_max_y, current_max_x) = acc
      let common.Coord(next_x, next_y) = key

      #(int.max(current_max_y, next_y), int.max(current_max_x, next_x))
    },
  )
}

fn dict_into_two_d_array(input: dict.Dict(common.Coord, a)) -> List(List(a)) {
  let #(max_y, max_x) = bounds_from_dict(input)

  common.array_with_length(max_y)
  |> list.map(fn(y) {
    common.array_with_length(max_x)
    |> list.map(fn(x) {
      let assert Ok(el) = dict.get(input, common.Coord(x, y))

      el
    })
  })
}

fn in_bounds(coord: common.Coord, dims: common.Coord) -> Bool {
  coord.x >= 0 && coord.x <= dims.x && coord.y >= 0 && coord.y <= dims.y
}

fn coord_from_dir(coord: common.Coord, dir: Direction) -> common.Coord {
  case dir {
    North -> common.Coord(coord.x, coord.y - 1)
    South -> common.Coord(coord.x, coord.y + 1)
    East -> common.Coord(coord.x + 1, coord.y)
    West -> common.Coord(coord.x - 1, coord.y)
  }
}

fn get_next_coord_from_dir(
  coord: common.Coord,
  board_map: dict.Dict(common.Coord, BoardElement),
  board_dimensions: common.Coord,
  direction: Direction,
) -> common.Coord {
  let next = coord_from_dir(coord, direction)
  case in_bounds(next, board_dimensions) {
    True -> {
      case dict.get(board_map, next) {
        Ok(EmptySpace) ->
          get_next_coord_from_dir(next, board_map, board_dimensions, direction)
        Ok(_) -> {
          coord
        }
        Error(_) -> {
          io.debug(#(next, board_dimensions))
          panic
        }
      }
    }
    False -> coord
  }
}

fn dict_swap(
  d: dict.Dict(common.Coord, a),
  a: common.Coord,
  b: common.Coord,
) -> dict.Dict(common.Coord, a) {
  let assert Ok(a_val) = dict.get(d, a)
  let assert Ok(b_val) = dict.get(d, b)

  d
  |> dict.insert(a, b_val)
  |> dict.insert(b, a_val)
}

fn compute_board(board: Board) -> Int {
  let common.Coord(_, max_y) = common.two_d_array_dims(board)
  board
  |> list.index_map(fn(col_idx, row) {
    row
    |> list.index_map(fn(_, el) {
      case el {
        RoundRock -> {
          max_y - col_idx + 1
        }
        _ -> 0
      }
    })
  })
  |> list.flatten
  |> int.sum
}

fn tilt_board_in_direction(
  input: #(dict.Dict(common.Coord, BoardElement), common.Coord),
  direction: Direction,
) -> dict.Dict(common.Coord, BoardElement) {
  let #(base_map, common.Coord(col_length, row_length)) = input
  let vertical_flip = fn(x: List(a)) {
    case direction {
      North | West -> x
      South | East ->
        x
        |> list.reverse
    }
  }

  common.array_with_length(row_length)
  |> vertical_flip
  |> list.fold(
    base_map,
    fn(map, row_idx) {
      common.array_with_length(col_length)
      |> vertical_flip
      |> list.fold(
        map,
        fn(map, col_idx) {
          let lookup = common.Coord(col_idx, row_idx)
          let assert Ok(el) =
            map
            |> dict.get(lookup)

          let next_coord = case el {
            RoundRock -> {
              get_next_coord_from_dir(
                lookup,
                map,
                common.Coord(col_length, row_length),
                direction,
              )
            }
            _ -> lookup
          }

          dict_swap(map, lookup, next_coord)
        },
      )
    },
  )
}

fn find_pattern(result: List(Int)) {
  let pattern =
    result
    |> list.reverse
    |> common.list_enumerate
    |> list.fold(
      dict.new(),
      fn(d, el) {
        let #(result, idx) = el
        common.upsert(d, result, [], fn(arr) { list.append(arr, [idx]) }).0
      },
    )
    |> common.dict_entries
    |> list.filter(fn(x) { list.length(pair.second(x)) > 2 })
    |> list.sort(fn(a, b) {
      let assert Ok(a) = list.first(pair.second(a))
      let assert Ok(b) = list.first(pair.second(b))

      int.compare(a, b)
    })
    |> list.map(fn(x) {
      #(
        pair.first(x),
        list.first(pair.second(x))
        |> common.unwrap_panic,
      )
    })

  pattern
  |> list.each(io.debug)

  let start_idx =
    list.first(pattern)
    |> common.unwrap_panic
    |> pair.second

  let num_iterations = 1_000_000_000 - start_idx
  let idx = num_iterations % list.length(pattern)

  let assert Ok(final_result) = list.at(pattern, idx)

  final_result
}

fn run_cycle(
  input: #(dict.Dict(common.Coord, BoardElement), common.Coord),
  cycles: Int,
) {
  let #(base_map, dimensions) = input
  let base_computation =
    base_map
    |> dict_into_two_d_array
    |> compute_board
  let #(last_map, result) =
    [[North, West, South, East]]
    |> iterator.from_list
    |> iterator.cycle
    |> iterator.take(cycles)
    |> iterator.fold_until(
      #(base_map, [base_computation]),
      fn(state, directions) {
        let #(map, computations) = state
        let next_map =
          directions
          |> list.fold(
            map,
            fn(map, direction) {
              tilt_board_in_direction(#(map, dimensions), direction)
            },
          )
        let next_computation =
          next_map
          |> dict_into_two_d_array
          |> compute_board

        list.Continue(#(next_map, [next_computation, ..computations]))
      },
    )

  find_pattern(result)
  |> pair.first
}

pub fn pt_1(input: String) {
  input
  |> parse_board
  |> two_d_array_into_dict
  |> tilt_board_in_direction(North)
  |> dict_into_two_d_array
  |> compute_board
}

pub fn pt_2(input: String) {
  input
  |> parse_board
  |> two_d_array_into_dict
  |> run_cycle(200)
}
