import gleam/int
import gleam/list
import gleam/string
import common
import gleam/dict
import gleam/result
import gleam/regex
import gleam/option

pub type Label {
  Addition(String, Int)
  Subtraction(String)
}

pub type LabelEntry =
  #(Int, Label)

fn get_codepoint_from_char(char: String) {
  case string.to_utf_codepoints(char) {
    [code_point] -> string.utf_codepoint_to_int(code_point)
  }
}

fn compute_hash(input: String) -> Int {
  input
  |> string.to_graphemes
  |> list.fold(
    0,
    fn(hash, char) {
      let ascii = get_codepoint_from_char(char)
      { { hash + ascii } * 17 } % 256
    },
  )
}

fn parse_label(input: String) -> Label {
  let assert Ok(label_rex) = regex.from_string("(.+)(=|-)(\\d)?")

  case regex.scan(label_rex, input) {
    [
      regex.Match(
        _,
        [option.Some(label), option.Some(_), option.Some(digit_str)],
      ),
    ] ->
      Addition(
        label,
        int.parse(digit_str)
        |> common.unwrap_expect("Couldnt parse digit string"),
      )
    [regex.Match(_, [option.Some(label), option.Some(_)])] -> Subtraction(label)
    _ -> panic
  }
}

fn into_label_entry(input: Label) -> LabelEntry {
  case input {
    Addition(label, _) -> #(compute_hash(label), input)
    Subtraction(label) -> #(compute_hash(label), input)
  }
}

fn boxify_label_entries(input: List(LabelEntry)) {
  input
  |> list.fold(
    dict.new(),
    fn(boxes, entry) {
      case entry {
        #(hash, Addition(label, focal_length)) ->
          common.upsert(
            boxes,
            hash,
            [],
            fn(x) { list.key_set(x, label, focal_length) },
          ).0
        #(hash, Subtraction(label)) ->
          common.update(
            boxes,
            hash,
            fn(v) {
              v
              |> list.filter(fn(lens) {
                let #(lens_label, _) = lens
                lens_label != label
              })
            },
          )
          |> result.unwrap(boxes)
      }
    },
  )
}

fn compute_focusing_power(box_entry: #(Int, List(#(String, Int)))) -> Int {
  let #(box_number, lenses) = box_entry
  let one_based_box_number = box_number + 1

  lenses
  |> list.index_map(fn(lens_idx, lens) {
    let one_based_idx = lens_idx + 1
    let #(_, focal_length) = lens
    one_based_box_number * one_based_idx * focal_length
  })
  |> int.sum
}

pub fn pt_1(input: String) {
  input
  |> string.split(",")
  |> list.map(compute_hash)
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> string.split(",")
  |> list.map(parse_label)
  |> list.map(into_label_entry)
  |> boxify_label_entries
  |> common.dict_entries
  |> list.map(compute_focusing_power)
  |> int.sum
}
