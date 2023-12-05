import gleam/list
import gleam/string
import gleam/regex
import gleam/int
import gleam/option
import gleam/result
import gleam/float
import gleam/dict
import gleam/pair
import common

type Card =
  #(List(Int), List(Int))

type NumberedCard =
  #(Int, List(Int), List(Int))

fn into_card(numbered_card: NumberedCard) -> Card {
  #(numbered_card.1, numbered_card.2)
}

fn trim_card_input(line: String) {
  let assert Ok(numbers) = case string.split_once(line, ":") {
    Ok(#(_, input)) -> Ok(input)
    _ -> Error(Nil)
  }

  numbers
}

fn parse_list_of_numbers_from(number_list: String) -> List(Int) {
  let assert Ok(rex_digit) = regex.from_string("(\\d+)")

  regex.scan(rex_digit, number_list)
  |> list.flat_map(fn(match) {
    case match {
      regex.Match(_, submatches) ->
        submatches
        |> list.map(fn(digit_str) {
          digit_str
          |> option.unwrap("-9999999")
          |> int.parse
        })
    }
  })
  |> result.values
}

fn parse_line_into_card(line: String) -> Card {
  let assert Ok(card) = case string.split_once(line, "|") {
    Ok(#(winning_numbers_str, card_numbers_string)) -> {
      Ok(#(
        parse_list_of_numbers_from(winning_numbers_str),
        parse_list_of_numbers_from(card_numbers_string),
      ))
    }
    _ -> Error(Nil)
  }

  card
}

fn parse_line_into_numbered_card(line: String) -> NumberedCard {
  let assert Ok(card_rex_id) = regex.from_string("Card\\s+(\\d+):")
  let assert Ok(card_id) = case regex.scan(card_rex_id, line) {
    [regex.Match(_, [option.Some(id)])] -> int.parse(id)
    _ -> Error(Nil)
  }
  let card =
    line
    |> trim_card_input
    |> parse_line_into_card
  let numbered_card = #(card_id, card.0, card.1)

  numbered_card
}

fn count_matches_in_card(card: Card) {
  card.1
  |> list.fold(
    0,
    fn(acc, el) {
      case list.contains(card.0, el) {
        True -> acc + 1
        False -> acc
      }
    },
  )
}

fn count_matches_in_numbered_card(card: NumberedCard) {
  #(card.0, count_matches_in_card(into_card(card)))
}

fn compute_score_on_card(number_of_matches: Int) -> Int {
  case number_of_matches {
    0 -> 0
    n ->
      2
      |> int.power(int.to_float(n - 1))
      |> result.unwrap(-99_999.0)
      |> float.round
  }
}

fn fold_range_into_copies(
  copies: dict.Dict(Int, Int),
  card: #(Int, Int),
  number_of_current_copies: Int,
) {
  list.range(card.0 + 1, card.0 + card.1)
  |> list.fold(
    copies,
    fn(acc, el) {
      case dict.get(acc, el) {
        Ok(val) -> dict.insert(acc, el, { val + { number_of_current_copies } })
        _ -> dict.insert(acc, el, number_of_current_copies)
      }
    },
  )
}

fn fold_winning_copies(copies: dict.Dict(Int, Int), card: #(Int, Int)) {
  copies
  |> common.upsert(card.0, 0, fn(x) { x + 1 })
  |> fn(copies) {
    let #(copies, number_of_current_copies) = copies

    case card.1 {
      0 -> copies
      _ -> fold_range_into_copies(copies, card, number_of_current_copies)
    }
  }
}

pub fn pt_1(input: String) {
  input
  |> string.split("\n")
  |> list.map(trim_card_input)
  |> list.map(parse_line_into_card)
  |> list.map(count_matches_in_card)
  |> list.map(compute_score_on_card)
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> string.split("\n")
  |> list.map(parse_line_into_numbered_card)
  |> list.map(count_matches_in_numbered_card)
  |> list.fold(dict.new(), fold_winning_copies)
  |> dict.to_list
  |> list.map(pair.second)
  |> int.sum
}
