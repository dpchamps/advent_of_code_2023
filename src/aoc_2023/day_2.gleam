import gleam/string
import gleam/result
import gleam/list
import gleam/int
import gleam/regex
import gleam/option

type Color {
  Red(Int)
  Blue(Int)
  Green(Int)
}

type Game =
  #(Int, Int, Int, Int)

type ColorSelector =
  fn(#(Int, Int, Int), Color) -> #(Int, Int, Int)

fn into_color_string_quantity(match: regex.Match) -> Result(Color, Nil) {
  case match.submatches {
    [option.Some(quantity), option.Some(color)] -> {
      let assert Ok(q_parsed) = int.parse(quantity)
      case
        color
        |> string.lowercase
      {
        "red" -> Ok(Red(q_parsed))
        "green" -> Ok(Green(q_parsed))
        "blue" -> Ok(Blue(q_parsed))
        _ -> Error(Nil)
      }
    }
  }
}

fn parse_game_id_color_string_into_game(
  partial: #(Int, String),
  initial: #(Int, Int, Int),
  selector: ColorSelector,
) -> Game {
  let assert Ok(color_string_rex) = regex.from_string("(\\d+) (\\w+)")
  let max_color =
    partial.1
    |> string.split(";")
    |> list.flat_map(fn(x) {
      regex.scan(color_string_rex, x)
      |> list.map(into_color_string_quantity)
      |> result.values
    })
    |> list.fold(initial, selector)

  #(partial.0, max_color.0, max_color.1, max_color.2)
}

fn parse_game_id_color_string_into_game_from_max(partial: #(Int, String)) {
  partial
  |> parse_game_id_color_string_into_game(
    #(0, 0, 0),
    fn(acc, color) {
      case color {
        Red(q) -> #(int.max(acc.0, q), acc.1, acc.2)
        Green(q) -> #(acc.0, int.max(acc.1, q), acc.2)
        Blue(q) -> #(acc.0, acc.1, int.max(acc.2, q))
      }
    },
  )
}

fn parse_lines_into_games(
  lines: List(String),
  game_parser: fn(#(Int, String)) -> Game,
) -> List(Game) {
  let assert Ok(game_id_rex) = regex.from_string("Game (\\d+?): (.*)")

  lines
  |> list.map(fn(line) {
    case regex.scan(game_id_rex, line) {
      [regex.Match(_, [option.Some(game_id), option.Some(color_text)])] -> {
        let assert Ok(game_id_num) = int.parse(game_id)
        Ok(#(game_id_num, color_text))
      }
      _ -> Error(Nil)
    }
  })
  |> result.values
  |> list.map(game_parser)
}

fn satisfies_constraint(game: Game, constraint: #(Int, Int, Int)) -> Bool {
  case game {
    #(_, red_quantity, green_quantity, blue_quantity) if red_quantity <= constraint.0 && green_quantity <= constraint.1 && blue_quantity <= constraint.2 ->
      True
    _ -> False
  }
}

fn compute_power_set(game: Game) -> Int {
  game.1 * game.2 * game.3
}

pub fn pt_1(input: String) {
  input
  |> string.split("\n")
  |> parse_lines_into_games(parse_game_id_color_string_into_game_from_max)
  |> list.filter(fn(x) { satisfies_constraint(x, #(12, 13, 14)) })
  |> list.map(fn(g) { g.0 })
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> string.split("\n")
  |> parse_lines_into_games(parse_game_id_color_string_into_game_from_max)
  |> list.map(compute_power_set)
  |> int.sum
}
