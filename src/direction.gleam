import common

pub type Direction {
  North
  South
  East
  West
}

pub type Parity {
  Left
  Right
}

pub fn ninty_degree_turn(start_dir: Direction, parity: Parity) -> Direction {
  case start_dir, parity {
    North, Left -> West
    North, Right -> East
    East, Left -> North
    East, Right -> South
    South, Left -> East
    South, Right -> West
    West, Left -> South
    West, Right -> North
  }
}

pub fn get_next_coord_from_direction(
  start: common.Coord,
  direction: Direction,
  steps: Int,
) -> common.Coord {
  let common.Coord(x, y) = start
  case direction {
    North -> common.Coord(x, y - steps)
    South -> common.Coord(x, y + steps)
    East -> common.Coord(x + steps, y)
    West -> common.Coord(x - steps, y)
  }
}

pub fn is_in_bounds(coord: common.Coord, bounds: common.Coord) -> Bool {
  let common.Coord(max_x, max_y) = bounds
  let common.Coord(x, y) = coord
  x >= 0 && x <= max_x && y >= 0 && y <= max_y
}
