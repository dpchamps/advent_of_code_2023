import gleam/int
import gleam/list
import gleam/string
import common
import gleam/io
import gleam/set

pub type Tile {
  Empty
  Mirror(Angle)
  Splitter(Splitter)
}

pub type Angle {
  // /
  WestEast
  // \
  EastWest
}

pub type Splitter {
  // -
  Horizontal
  // |
  Vertical
}

pub type Grid =
  List(List(Tile))

pub type Direction {
  North
  South
  East
  West
}

fn turn_direction_90_degrees(direction: Direction, towards: Angle) -> Direction {
  case direction, towards {
    North, WestEast -> East
    North, EastWest -> West

    East, WestEast -> North
    East, EastWest -> South

    South, WestEast -> West
    South, EastWest -> East

    West, WestEast -> South
    West, EastWest -> North
  }
}

fn directions_of_splitter(
  direction: Direction,
  splitter: Splitter,
) -> List(Direction) {
  case direction, splitter {
    East, Horizontal | West, Horizontal -> [direction]
    East, Vertical | West, Vertical -> [North, South]
    North, Vertical | South, Vertical -> [direction]
    North, Horizontal | South, Horizontal -> [East, West]
  }
}

fn char_of_tile(char: String) -> Tile {
  case char {
    "." -> Empty
    "/" -> Mirror(WestEast)
    "\\" -> Mirror(EastWest)
    "|" -> Splitter(Vertical)
    "-" -> Splitter(Horizontal)
  }
}

fn parse_input_into_grid(input: String) -> Grid {
  input
  |> string.split("\n")
  |> list.map(fn(line) {
    line
    |> string.to_graphemes
    |> list.map(char_of_tile)
  })
}

fn get_next_coord_from_direction(
  start: common.Coord,
  direction: Direction,
) -> common.Coord {
  let common.Coord(x, y) = start
  case direction {
    North -> common.Coord(x, y - 1)
    South -> common.Coord(x, y + 1)
    East -> common.Coord(x + 1, y)
    West -> common.Coord(x - 1, y)
  }
}

fn is_in_bounds(coord: common.Coord, bounds: common.Coord) -> Bool {
  let common.Coord(max_x, max_y) = bounds
  let common.Coord(x, y) = coord
  x >= 0 && x <= max_x && y >= 0 && y <= max_y
}

fn get_tile_from_coord(
  grid: Grid,
  bounds: common.Coord,
  coord: common.Coord,
) -> Result(Tile, Nil) {
  let common.Coord(col, row) = coord
  case is_in_bounds(coord, bounds) {
    False -> Error(Nil)
    True -> {
      let assert Ok(row) = list.at(grid, row)
      let assert Ok(tile) = list.at(row, col)

      Ok(tile)
    }
  }
}

fn get_coords_from_tile(
  coord: common.Coord,
  direction: Direction,
  tile: Tile,
) -> List(#(common.Coord, Direction)) {
  case tile {
    Empty -> [#(coord, direction)]
    Mirror(angle) -> [#(coord, turn_direction_90_degrees(direction, angle))]
    Splitter(splitter) ->
      directions_of_splitter(direction, splitter)
      |> list.map(fn(direction) { #(coord, direction) })
  }
}

// strategy:
// bfs through the map, adding next light positions
// until theres no more light to add. 
// mark light positions into a set
// the size of the set is the solution to the problem
// caveat, visited needs to track position and direction,
// but total squares visited must be just position

fn trace_light_bfs_inner(
  grid: Grid,
  queue: List(#(common.Coord, Direction)),
  bounds: common.Coord,
  visited: set.Set(#(common.Coord, Direction)),
  squares_with_light: set.Set(common.Coord),
) -> set.Set(common.Coord) {
  case queue {
    [next, ..remaining_queue] -> {
      case set.contains(visited, next) {
        True ->
          trace_light_bfs_inner(
            grid,
            remaining_queue,
            bounds,
            visited,
            squares_with_light,
          )
        False -> {
          let #(current_coord, current_direction) = next
          let next_visited = set.insert(visited, next)
          let next_squares_with_light =
            set.insert(squares_with_light, current_coord)

          let items_to_enqueue = case
            get_tile_from_coord(grid, bounds, current_coord)
          {
            Ok(tile) ->
              get_coords_from_tile(current_coord, current_direction, tile)
              |> list.map(fn(coord_dir) {
                let #(coord, dir) = coord_dir
                let next_coord = get_next_coord_from_direction(coord, dir)
                #(next_coord, dir)
              })
              |> list.filter(fn(cd) {
                let #(c, _) = cd
                is_in_bounds(c, bounds)
              })

            Error(_) -> []
          }

          let next_queue = list.append(remaining_queue, items_to_enqueue)

          trace_light_bfs_inner(
            grid,
            next_queue,
            bounds,
            next_visited,
            next_squares_with_light,
          )
        }
      }
    }
    [] -> squares_with_light
  }
}

fn trace_light_path(grid: Grid, start: #(common.Coord, Direction)) -> Int {
  let bounds = common.two_d_array_dims(grid)
  trace_light_bfs_inner(grid, [start], bounds, set.new(), set.new())
  |> set.size
}

fn find_largest_configuration(grid: Grid) -> Int {
  let bounds = common.two_d_array_dims(grid)

  let top_south =
    common.array_with_length(bounds.x)
    |> list.map(fn(x) { #(common.Coord(x, 0), South) })
  let bottom_north =
    common.array_with_length(bounds.x)
    |> list.map(fn(x) { #(common.Coord(x, bounds.y), North) })
  let left_east =
    common.array_with_length(bounds.y)
    |> list.map(fn(y) { #(common.Coord(0, y), East) })
  let right_west =
    common.array_with_length(bounds.y)
    |> list.map(fn(y) { #(common.Coord(bounds.x, y), West) })

  list.fold(
    [top_south, bottom_north, left_east, right_west]
    |> list.flatten(),
    -1,
    fn(max, start) {
      let result = trace_light_path(grid, start)

      int.max(max, result)
    },
  )
}

pub fn pt_1(input: String) {
  input
  |> parse_input_into_grid
  |> trace_light_path(#(common.Coord(0, 0), East))
}

pub fn pt_2(input: String) {
  input
  |> parse_input_into_grid
  |> find_largest_configuration
}
