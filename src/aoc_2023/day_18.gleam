import gleam/int
import gleam/list
import gleam/string
import common
import direction
import gleam/regex
import gleam/option
import gleam/pair
import gleam/float

pub type DigInstruction {
  DigInstruction(direction: direction.Direction, length: Int, color: String)
}

fn parse_direction_string(input: String) -> direction.Direction {
  case input {
    "R" -> direction.East
    "D" -> direction.South
    "L" -> direction.West
    "U" -> direction.North
  }
}

fn direction_of_number(input: String) -> direction.Direction {
  case input {
    "0" -> direction.East
    "1" -> direction.South
    "2" -> direction.West
    "3" -> direction.North
  }
}

fn parse_color_string(input: String) -> String {
  let assert Ok(color_rex) = regex.from_string("\\(#(.+)\\)")
  case regex.scan(color_rex, input) {
    [regex.Match(_, [option.Some(digit_string)])] -> {
      digit_string
    }
  }
}

fn parse_color_string_two(input: String) -> #(direction.Direction, Int) {
  case
    string.to_graphemes(input)
    |> list.split(5)
  {
    #(len, dir) -> {
      #(
        direction_of_number(string.join(dir, "")),
        string.join(len, "")
        |> int.base_parse(16)
        |> common.unwrap_panic,
      )
    }
  }
}

fn parse_line_into_dig_instruction(line: String) -> DigInstruction {
  case
    line
    |> string.split(" ")
  {
    [direction_string, length_string, color_string] -> {
      DigInstruction(
        parse_direction_string(direction_string),
        int.parse(length_string)
        |> common.unwrap_panic,
        parse_color_string(color_string),
      )
    }
  }
}

fn extract_dig_instructions(input: String) -> List(DigInstruction) {
  input
  |> string.split("\n")
  |> list.map(parse_line_into_dig_instruction)
}

fn carve_out_coords(input: List(DigInstruction)) -> #(Int, List(common.Coord)) {
  let perimeter =
    list.map(input, fn(x) { x.length })
    |> int.sum
  let polygon =
    input
    |> list.fold(
      #([common.Coord(0, 0)], common.Coord(0, 0)),
      fn(state, instruction) {
        let #(coords, pointer) = state
        let next_coord =
          direction.get_next_coord_from_direction(
            pointer,
            instruction.direction,
            instruction.length,
          )

        #(list.append(coords, [next_coord]), next_coord)
      },
    )
    |> pair.first
    |> offset_negative_coords

  #(perimeter, polygon)
}

fn offset_negative_coords(input: List(common.Coord)) -> List(common.Coord) {
  let min_coord =
    input
    |> list.fold(
      common.Coord(common.max_safe_int, common.max_safe_int),
      fn(min_coord, element) {
        common.Coord(
          int.min(min_coord.x, element.x),
          int.min(min_coord.y, element.y),
        )
      },
    )
  let offset = common.Coord(int.negate(min_coord.x), int.negate(min_coord.y))
  input
  |> list.map(fn(coord) { common.Coord(coord.x + offset.x, coord.y + offset.y) })
}

fn map_true_length(instructions: List(DigInstruction)) -> List(DigInstruction) {
  instructions
  |> list.map(fn(instruction) {
    let #(next_dir, next_len) = parse_color_string_two(instruction.color)
    DigInstruction(next_dir, next_len, instruction.color)
  })
}

fn compute_area(input: #(Int, List(common.Coord))) -> Int {
  let #(perimeter, polygon) = input
  let adjust = { perimeter / 2 } + 1

  let interior =
    polygon
    |> list.window_by_2
    |> list.fold(
      0,
      fn(area, coord_window) {
        let #(coord_a, coord_b) = coord_window
        let next = { coord_a.x * coord_b.y } - { coord_b.x * coord_a.y }

        area + next
      },
    )
    |> int.absolute_value
    |> int.to_float
    |> fn(x) { x /. 2.0 }
    |> float.round

  adjust + interior
}

pub fn pt_1(input: String) {
  input
  |> extract_dig_instructions
  |> carve_out_coords
  |> compute_area
}

pub fn pt_2(input: String) {
  input
  |> extract_dig_instructions
  |> map_true_length
  |> carve_out_coords
  |> compute_area
}
