import gleam/int
import gleam/list
import gleam/string
import common
import gleam/io
import gleam/dict
import gleam/set
import gleam/pair
import gleam/iterator
import gleam/result

pub type Direction {
  North
  South
  East
  West
}

pub type Passages =
  List(Direction)

pub type Coord {
  Coord(x: Int, y: Int)
}

pub type PipeType {
  Passage(String)
  Ground
  Start
}

pub type Cell {
  Cell(passages: Passages, coord: Coord, pipe_type: PipeType)
}

pub type PipeMap =
  dict.Dict(Coord, Cell)

fn add_cord(coord_a: Coord, coord_b: Coord) -> Coord {
  Coord(coord_a.x + coord_b.x, coord_a.y + coord_b.y)
}

fn opposite_direction(direction: Direction) -> Direction {
  case direction {
    North -> South
    South -> North
    East -> West
    West -> East
  }
}

fn direction_of_coord(direction: Direction) -> Coord {
  case direction {
    North -> Coord(0, -1)
    South -> Coord(0, 1)
    East -> Coord(1, 0)
    West -> Coord(-1, 0)
  }
}

fn pipe_type_to_text(pipe_type: PipeType) {
  case pipe_type {
    Passage(x) -> x
    Ground -> "."
    Start -> "S"
  }
}

fn coord_in_bounds(bounds: #(Coord, Coord), coord: Coord) -> Bool {
  let #(min, max) = bounds
  let result =
    coord.x >= min.x && coord.x <= max.x && coord.y >= min.y && coord.y <= max.y

  result
}

fn bounds_from_map(pipe_map: PipeMap) -> #(Coord, Coord) {
  pipe_map
  |> dict.keys
  |> list.fold(
    #(Coord(common.max_safe_int, common.max_safe_int), Coord(-1000, -1000)),
    fn(acc, coord) {
      let #(min, max) = acc

      #(
        Coord(int.min(min.x, coord.x), int.min(min.y, coord.y)),
        Coord(int.max(max.x, coord.x), int.max(max.y, coord.y)),
      )
    },
  )
}

fn get_next_coord(direction: Direction, start: Coord) -> Coord {
  direction
  |> direction_of_coord
  |> add_cord(start)
}

fn pipe_to_passages(pipe: PipeType) -> Passages {
  case pipe {
    Passage("|") -> [North, South]
    Passage("-") -> [East, West]
    Passage("L") -> [North, East]
    Passage("J") -> [North, West]
    Passage("7") -> [South, West]
    Passage("F") -> [South, East]
    Ground -> []
    Start -> []
  }
}

fn char_to_pipe_type(pipe: String) -> PipeType {
  case pipe {
    "|" -> Passage("|")
    "-" -> Passage("-")
    "L" -> Passage("L")
    "J" -> Passage("J")
    "7" -> Passage("7")
    "F" -> Passage("F")
    "." -> Ground
    "S" -> Start
  }
}

fn pipe_type_from_passages(passages: Passages) {
  case passages {
    [North, South] -> Passage("|")
    [East, West] -> Passage("-")
    [North, East] -> Passage("L")
    [North, West] -> Passage("J")
    [South, West] -> Passage("7")
    [South, East] -> Passage("F")
    _ -> panic("Undecidable pipe type")
  }
}

fn is_bend(pipe_type: PipeType) -> Bool {
  case pipe_type {
    Passage("L") | Passage("J") | Passage("7") | Passage("F") -> True
    _ -> False
  }
}

fn parse_char_into_cell(char: String, coord: Coord) -> Cell {
  char
  |> char_to_pipe_type
  |> fn(p_type) { Cell(pipe_to_passages(p_type), coord, p_type) }
}

fn parse_line_into_cells(line: String, y_pos: Int) -> List(Cell) {
  line
  |> string.to_graphemes
  |> list.index_map(fn(x_pos, char) {
    parse_char_into_cell(char, Coord(x_pos, y_pos))
  })
}

fn parse_input_into_pipe_map(input: String) -> PipeMap {
  input
  |> string.split("\n")
  |> list.index_fold(
    dict.new(),
    fn(pipe_map, pipe_line, y_pos) {
      pipe_line
      |> parse_line_into_cells(y_pos)
      |> list.fold(
        pipe_map,
        fn(p_map, cell) {
          p_map
          |> dict.insert(cell.coord, cell)
        },
      )
    },
  )
}

fn get_start_cell(pipe_map: PipeMap) -> Cell {
  pipe_map
  |> dict.values
  |> list.find(fn(cell) {
    case cell {
      Cell(_, _, Start) -> True
      _ -> False
    }
  })
  |> common.unwrap_panic
}

fn resolve_start_coord(pipe_map: PipeMap) -> PipeMap {
  pipe_map
  |> get_start_cell
  |> fn(start_cell: Cell) {
    [North, South, East, West]
    |> list.fold(
      #(start_cell, []),
      fn(acc, direction) {
        let #(start_cell, passages) = acc
        case
          pipe_map
          |> dict.get(
            direction
            |> direction_of_coord
            |> add_cord(start_cell.coord),
          )
        {
          Ok(Cell(neighbor_cell_passages, _, _)) -> {
            case
              neighbor_cell_passages
              |> list.any(fn(neighbor_dir) {
                neighbor_dir == direction
                |> opposite_direction
              })
            {
              True -> #(
                start_cell,
                passages
                |> list.append([direction]),
              )
              False -> acc
            }
          }
          _ -> acc
        }
      },
    )
    |> fn(start_cell_passages: #(Cell, List(Direction))) {
      let #(start_cell, passages) = start_cell_passages
      let new_start_cell =
        Cell(passages, start_cell.coord, start_cell.pipe_type)

      pipe_map
      |> dict.insert(new_start_cell.coord, new_start_cell)
    }
  }
}

fn plumb_pipe_map_bfs(
  pipe_map: PipeMap,
  queue: List(#(Coord, Int)),
  visited: set.Set(Coord),
  max_dist: Int,
  inside_map: dict.Dict(Coord, List(Coord)),
) -> #(Int, set.Set(Coord)) {
  case queue {
    [#(coord, last_dist), ..next_queue] -> {
      case
        visited
        |> set.contains(coord)
      {
        True ->
          plumb_pipe_map_bfs(
            pipe_map,
            next_queue,
            visited,
            max_dist,
            inside_map,
          )
        False -> {
          let updated_visited =
            visited
            |> set.insert(coord)
          let updated_queue =
            pipe_map
            |> dict.get(coord)
            |> common.unwrap_panic
            |> fn(cell: Cell) {
              cell.passages
              |> list.map(fn(direction) {
                #(direction, get_next_coord(direction, cell.coord))
              })
            }
            |> fn(next_coords) {
              queue
              |> list.append(
                next_coords
                |> list.map(fn(c: #(Direction, Coord)) { #(c.1, last_dist + 1) }),
              )
            }

          plumb_pipe_map_bfs(
            pipe_map,
            updated_queue,
            updated_visited,
            int.max(last_dist, max_dist),
            inside_map,
          )
        }
      }
    }
    _ -> #(max_dist, visited)
  }
}

fn plumb_pipe_map(pipe_map: PipeMap) -> #(Int, set.Set(Coord)) {
  let start_cell = get_start_cell(pipe_map)

  plumb_pipe_map_bfs(
    pipe_map,
    [#(start_cell.coord, 0)],
    set.new(),
    0,
    dict.new(),
  )
}

fn flood_fill_bfs(
  avoid: set.Set(Coord),
  bounds: #(Coord, Coord),
  stack: List(Coord),
  visited: set.Set(Coord),
  discovered: List(Coord),
  inside_map: dict.Dict(Coord, List(Direction)),
  is_inside: Bool,
) -> #(List(Coord), Bool) {
  case stack {
    [coord, ..next_stack] -> {
      case
        visited
        |> set.contains(coord)
      {
        True ->
          flood_fill_bfs(
            avoid,
            bounds,
            next_stack,
            visited,
            discovered,
            inside_map,
            is_inside,
          )
        False -> {
          let updated_visited =
            visited
            |> set.insert(coord)

          let cardinal_dirs =
            [North, South, East, West]
            |> list.map(fn(direction) {
              // place we're moving to
              let next_coord =
                direction_of_coord(direction)
                |> add_cord(coord)
              let is_inside = case
                inside_map
                |> dict.get(next_coord)
              {
                Ok(inside_directions) -> {
                  let edge =
                    inside_directions
                    |> list.contains(
                      direction
                      |> opposite_direction,
                    )

                  case edge {
                    n if n == False && is_inside == True -> {
                      panic(
                        "Reached an impossible case where an island is both inside and outside",
                      )
                    }
                    _ -> #()
                  }

                  edge
                }

                _ -> False
              }

              #(next_coord, is_inside)
            })

          let next_is_inside =
            cardinal_dirs
            |> list.fold(
              False,
              fn(acc, x) {
                let #(_, found_inside) = x

                acc || found_inside
              },
            )

          let updated_stack =
            cardinal_dirs
            |> list.filter(fn(next_tuple) {
              let #(next_coord, _) = next_tuple
              coord_in_bounds(bounds, next_coord) && !{
                avoid
                |> set.contains(next_coord)
              }
            })
            |> list.map(pair.first)
            |> fn(next_coords) {
              stack
              |> list.append(next_coords)
            }

          let updated_discovered =
            discovered
            |> list.append([coord])

          flood_fill_bfs(
            avoid,
            bounds,
            updated_stack,
            updated_visited,
            updated_discovered,
            inside_map,
            is_inside || next_is_inside,
          )
        }
      }
    }
    [] -> {
      #(discovered, is_inside)
    }
  }
}

fn flood_fill_islands(
  input: List(Coord),
  avoid: set.Set(Coord),
  bounds: #(Coord, Coord),
  inside_map: dict.Dict(Coord, List(Direction)),
) -> List(#(List(Coord), Bool)) {
  case input {
    [] -> []
    [next, ..input] -> {
      let island =
        flood_fill_bfs(avoid, bounds, [next], set.new(), [], inside_map, False)
      let next_input =
        input
        |> list.filter(fn(coord) {
          !{
            island.0
            |> list.contains(coord)
          }
        })

      let next_islands =
        flood_fill_islands(next_input, avoid, bounds, inside_map)

      case next_islands {
        [] -> [island]
        _ -> [island, ..next_islands]
      }
    }
  }
}

fn find_left_top_most_pipe(pipe_circuit: List(Coord)) -> Coord {
  case pipe_circuit {
    [head, ..tail] ->
      tail
      |> list.fold(
        head,
        fn(top_left_most, next) {
          case top_left_most.x {
            n if n < next.x -> top_left_most
            n if n > next.x -> next
            n if n == next.x ->
              case top_left_most.y {
                n if n > next.y -> next
                _ -> top_left_most
              }
          }
        },
      )
  }
}

fn choose_anti_clockwise_passage(
  passages: Passages,
  direction: Direction,
) -> Direction {
  case passages {
    [North, East] | [North, West] | [South, West] | [South, East] -> {
      passages
      |> list.find(fn(dir) { direction == dir })
      |> common.unwrap_expect("Reached an undecidable bend")
    }
    [] -> panic("Undecidable pipe type")
    _ ->
      case
        passages
        |> list.contains(direction)
      {
        False -> panic("Impossible condition")
        True -> direction
      }
  }
}

fn get_direction_from_pipe(
  existing_direction: Direction,
  passages: Passages,
) -> Direction {
  case
    passages
    |> pipe_type_from_passages
  {
    Passage("L") | Passage("J") | Passage("7") | Passage("F") -> {
      passages
      |> list.find(fn(x) {
        x != existing_direction
        |> opposite_direction
      })
      |> common.unwrap_panic
    }
    _ -> existing_direction
  }
}

fn de_dupe_dir(direction: Direction, dirs: List(Direction)) -> List(Direction) {
  [direction, ..dirs]
  |> set.from_list
  |> set.to_list
}

fn get_inside_orientation(
  direction: Direction,
  passages: Passages,
  last_inside: List(Direction),
  from_direction: Direction,
) -> List(Direction) {
  let real_passages = case
    passages
    |> pipe_type_from_passages
    |> is_bend
  {
    // When there's a bend, we want to take all of the last inside directions that aren't
    // heading in the direction we just moved from, or are in the current passages
    True ->
      last_inside
      |> list.filter(fn(x) {
        x != from_direction && !{ list.contains(passages, x) }
      })

    _ -> []
  }
  case direction {
    North -> de_dupe_dir(West, real_passages)
    South -> de_dupe_dir(East, real_passages)
    East -> de_dupe_dir(North, real_passages)
    West -> de_dupe_dir(South, real_passages)
  }
}

// Datastructure returens a list of coords paired with the corresponding "inside coords"
fn trace_pipe_map_anti_clockwise(
  pipe_map: PipeMap,
  coord: Coord,
  direction: Direction,
  visited: set.Set(Coord),
  last_inside: List(Direction),
) -> List(#(Coord, List(Direction))) {
  case set.contains(visited, coord) {
    True -> []
    _ -> {
      let cell =
        pipe_map
        |> dict.get(coord)
        |> common.unwrap_panic

      let next_direction = get_direction_from_pipe(direction, cell.passages)
      let inside_dirs =
        get_inside_orientation(
          next_direction,
          cell.passages,
          last_inside,
          direction,
        )

      let move_towards =
        choose_anti_clockwise_passage(cell.passages, next_direction)
        |> direction_of_coord
        |> add_cord(coord)

      let next_cell =
        pipe_map
        |> dict.get(move_towards)
        |> common.unwrap_panic

      let next_visited =
        visited
        |> set.insert(coord)

      [
        #(coord, inside_dirs),
        ..trace_pipe_map_anti_clockwise(
          pipe_map,
          next_cell.coord,
          next_direction,
          next_visited,
          inside_dirs,
        )
      ]
    }
  }
}

pub fn pt_1(input: String) {
  input
  |> parse_input_into_pipe_map
  |> resolve_start_coord
  |> plumb_pipe_map
  |> pair.first
}

pub fn visualize_pipe_island(
  pipe_map: PipeMap,
  pipe_circuit: List(Coord),
  islands: List(#(List(Coord), Bool)),
  map_bounds: #(Coord, Coord),
) {
  let max_dim =
    map_bounds
    |> pair.second
  let empty_row =
    iterator.iterate(0, common.identity)
    |> iterator.take(max_dim.x + 1)
    |> iterator.to_list
  let empty =
    iterator.iterate(empty_row, fn(_) { empty_row })
    |> iterator.take(max_dim.y + 1)
    |> iterator.to_list

  let visual_map =
    pipe_circuit
    |> list.fold(
      dict.new(),
      fn(vis, coord) {
        let pipe =
          pipe_map
          |> dict.get(coord)
          |> common.unwrap_panic
          |> fn(x: Cell) {
            x.pipe_type
            |> pipe_type_to_text
          }

        vis
        |> dict.insert(coord, pipe)
      },
    )
    |> fn(vis_with_pipes) {
      islands
      |> list.fold(
        vis_with_pipes,
        fn(vis, island) {
          island.0
          |> list.fold(
            vis,
            fn(vis, coord) {
              vis
              |> dict.insert(
                coord,
                case island.1 {
                  True -> "I"
                  False -> "O"
                },
              )
            },
          )
        },
      )
    }

  let populated =
    empty
    |> list.index_map(fn(col_num, row) {
      row
      |> list.index_map(fn(row_num, _) {
        visual_map
        |> dict.get(Coord(row_num, col_num))
        |> common.unwrap_panic
      })
    })
  populated
  |> list.each(fn(x) {
    io.debug(
      x
      |> string.join(""),
    )
  })
}

pub fn pt_2(input: String) {
  input
  |> parse_input_into_pipe_map
  |> resolve_start_coord
  |> fn(p_map) {
    let map_bounds = bounds_from_map(p_map)
    io.debug(#("Map Bounds", map_bounds))
    let pipe_loop_coord_set =
      p_map
      |> plumb_pipe_map
      |> pair.second

    let coords_to_check =
      p_map
      |> dict.values
      |> list.map(fn(cell) { cell.coord })
      |> set.from_list
      |> common.set_subtraction(pipe_loop_coord_set)

    let top_left_most_pipe =
      find_left_top_most_pipe(
        pipe_loop_coord_set
        |> set.to_list,
      )

    let inside_map =
      trace_pipe_map_anti_clockwise(
        p_map,
        top_left_most_pipe,
        East,
        set.new(),
        [],
      )
      |> dict.from_list

    let islands =
      flood_fill_islands(
        coords_to_check
        |> set.to_list,
        pipe_loop_coord_set,
        map_bounds,
        inside_map,
      )

    visualize_pipe_island(
      p_map,
      pipe_loop_coord_set
      |> set.to_list,
      islands,
      map_bounds,
    )

    islands
    |> list.filter(pair.second)
    |> list.map(pair.first)
    |> list.map(list.length)
    |> int.sum
  }
}
