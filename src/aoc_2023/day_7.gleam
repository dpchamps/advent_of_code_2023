import gleam/int
import gleam/list
import gleam/string
import common
import gleam/order

pub type Card {
  Face(Int)
  Number(Int)
  Joker(Int)
}

pub type HandType {
  FiveOfAKind
  FourOfAKind
  FullHouse
  ThreeOfAKind
  TwoPair
  OnePair
  HighCard
}

pub type Hand =
  List(Card)

pub type HandBid =
  #(Hand, Int)

fn parse_card(input: String) -> Card {
  case int.parse(input) {
    Ok(n) -> Number(n)
    _ ->
      Face(
        input
        |> face_to_val,
      )
  }
}

fn face_to_val(input: String) {
  case input {
    "T" -> 10
    "J" -> 11
    "Q" -> 12
    "K" -> 13
    "A" -> 14
    _ -> panic
  }
}

fn hand_type_to_val(hand_type: HandType) {
  case hand_type {
    FiveOfAKind -> 7
    FourOfAKind -> 6
    FullHouse -> 5
    ThreeOfAKind -> 4
    TwoPair -> 3
    OnePair -> 2
    HighCard -> 1
  }
}

fn card_to_val(card: Card) {
  case card {
    Number(i) -> i
    Face(f) -> f
    Joker(j) -> j
  }
}

fn hand_into_value_chunks(hand: Hand) {
  hand
  |> list.map(card_to_val)
  |> list.sort(int.compare)
  |> list.chunk(fn(x) { x })
  |> list.sort(fn(a, b) {
    int.compare(list.length(a), list.length(b))
    |> order.negate
  })
}

fn hand_of_hand_type(hand: Hand) {
  case
    hand
    |> hand_into_value_chunks
  {
    [[_, _, _, _, _]] -> FiveOfAKind
    [[_, _, _, _], ..] -> FourOfAKind
    [[_, _, _], [_, _]] -> FullHouse
    [[_, _, _], ..] -> ThreeOfAKind
    [[_, _], [_, _], ..] -> TwoPair
    [[_, _], ..] -> OnePair
    [[_], ..] -> HighCard
  }
}

fn compare_card(card_a: Card, card_b: Card) {
  case card_a {
    Number(n_a) ->
      case card_b {
        Number(n_b) -> int.compare(n_a, n_b)
        Face(_) -> order.Lt
        Joker(_) -> order.Gt
      }
    Face(f_a) ->
      case card_b {
        Number(_) -> order.Gt
        Face(f_b) -> int.compare(f_a, f_b)
        Joker(_) -> order.Gt
      }
    Joker(_) ->
      case card_b {
        Joker(_) -> order.Eq
        _ -> order.Lt
      }
  }
}

fn compare_hand_type(hand_type_a: HandType, hand_type_b: HandType) {
  int.compare(hand_type_to_val(hand_type_a), hand_type_to_val(hand_type_b))
}

fn compare_hand_secondary(zipped_hands: List(#(Card, Card))) {
  case zipped_hands {
    [#(card_a, card_b), ..rest] -> {
      case compare_card(card_a, card_b) {
        order.Eq -> compare_hand_secondary(rest)
        ord -> ord
      }
    }
    _ -> panic
  }
}

fn compare_hand(hand_a: Hand, hand_b: Hand) {
  case
    compare_hand_type(
      hand_a
      |> hand_of_hand_type,
      hand_b
      |> hand_of_hand_type,
    )
  {
    order.Eq -> {
      compare_hand_secondary(
        hand_a
        |> list.zip(hand_b),
      )
    }
    ord -> ord
  }
}

fn compare_hand_bid(hand_bid_a: HandBid, hand_bid_b: HandBid) {
  compare_hand(hand_bid_a.0, hand_bid_b.0)
}

fn parse_line_into_hand_bid(line: String) -> HandBid {
  case
    line
    |> string.split(" ")
  {
    [hand, bid] -> #(
      hand
      |> string.to_graphemes
      |> list.map(parse_card),
      int.parse(bid)
      |> common.unwrap_panic,
    )
  }
}

pub fn hand_into_joker_hand(hand: Hand) {
  hand
  |> list.map(fn(card) {
    case card {
      Face(f) if f == 11 -> Joker(0)
      c -> c
    }
  })
}

pub fn is_joker(card: Card) {
  case card {
    Joker(_) -> True
    _ -> False
  }
}

pub fn select_best_card_for_joker_hand(hand: Hand) {
  case common.list_take_one(hand, is_joker) {
    Ok(#(hand_without_a_joker, index_of_joker)) -> {
      let next_hand = select_best_card_for_joker_hand(hand_without_a_joker)
      let joker_with_val =
        case
          next_hand
          |> hand_into_value_chunks
        {
          [[_, _, _, x], ..] -> x
          [[_, _, x], ..] -> x
          [[_, x], [_, _], ..] -> x
          [[_, x], ..] -> x
          [[x], ..] -> x
          [] -> 14
        }
        |> fn(x) { Joker(x) }
      next_hand
      |> common.list_insert_at(joker_with_val, index_of_joker)
    }
    _ -> hand
  }
}

pub fn pt_1(input: String) {
  input
  |> string.split("\n")
  |> list.map(parse_line_into_hand_bid)
  |> list.sort(compare_hand_bid)
  |> list.index_map(fn(rank, hand_bid) { { rank + 1 } * hand_bid.1 })
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> string.split("\n")
  |> list.map(parse_line_into_hand_bid)
  |> list.map(fn(x) { #(hand_into_joker_hand(x.0), x.1) })
  |> list.map(fn(x) { #(select_best_card_for_joker_hand(x.0), x.1) })
  |> list.sort(compare_hand_bid)
  |> list.index_map(fn(rank, hand_bid) { { rank + 1 } * hand_bid.1 })
  |> int.sum
}
