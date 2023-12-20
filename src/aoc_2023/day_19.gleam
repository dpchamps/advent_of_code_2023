import gleam/int
import gleam/list
import gleam/string
import common
import direction
import gleam/regex
import gleam/option
import gleam/pair
import gleam/float
import gleam/order
import gleam/dict
import gleam/io
import gleam/set
import gleam/queue
import gleam_community/maths/arithmetics

pub type RulesetMap =
  dict.Dict(String, Ruleset)

pub type Ruleset =
  List(Rule)

pub type Label {
  RuleLabel(String)
  Accepted
  Rejected
}

pub type Rule {
  Auto(label: Label)
  Inequality(part_name: String, order: order.Order, value: Int, label: Label)
}

pub type Part =
  dict.Dict(String, Int)

fn order_of_string(input: String) -> order.Order {
  case input {
    "<" -> order.Lt
    ">" -> order.Gt
  }
}

fn label_of_string(input: String) -> Label {
  case input {
    "R" -> Rejected
    "A" -> Accepted
    label -> RuleLabel(label)
  }
}

fn parse_rule_string_into_rules(rule_string: String) -> List(Rule) {
  let assert Ok(rule_rex) = regex.from_string("(.+)([<|>])(\\d.+):(.+)")

  rule_string
  |> string.split(",")
  |> list.map(fn(raw_rule) {
    case regex.scan(rule_rex, raw_rule) {
      [
        regex.Match(
          _,
          [
            option.Some(part_name),
            option.Some(inequality),
            option.Some(value),
            option.Some(label),
          ],
        ),
      ] -> {
        Inequality(
          part_name,
          order_of_string(inequality),
          int.parse(value)
          |> common.unwrap_panic,
          label_of_string(label),
        )
      }
      _ -> Auto(label_of_string(raw_rule))
    }
  })
}

fn parse_line_into_ruleset(line: String) -> #(String, List(Rule)) {
  let assert Ok(rule_rex) = regex.from_string("(.+){(.+)}")

  case regex.scan(rule_rex, line) {
    [regex.Match(_, [option.Some(name), option.Some(rule_string)])] -> #(
      name,
      parse_rule_string_into_rules(rule_string),
    )
  }
}

fn parse_line_into_partlist(line: String) -> Part {
  line
  |> string.replace("{", "")
  |> string.replace("}", "")
  |> string.split(",")
  |> list.map(fn(part_quantity) {
    case string.split_once(part_quantity, "=") {
      Ok(#(part_name, value)) -> #(
        part_name,
        int.parse(value)
        |> common.unwrap_panic,
      )
      _ -> panic
    }
  })
  |> dict.from_list
}

fn get_rules_and_parts(input: String) -> #(RulesetMap, List(Part)) {
  case string.split_once(input, "\n\n") {
    Ok(#(rule_list, part_list)) -> {
      #(
        string.split(rule_list, "\n")
        |> list.map(parse_line_into_ruleset)
        |> dict.from_list,
        string.split(part_list, "\n")
        |> list.map(parse_line_into_partlist),
      )
    }
    _ -> panic
  }
}

fn apply_rule(part: Part, rule: Rule) -> Result(Label, Nil) {
  case rule {
    Auto(label) -> Ok(label)
    Inequality(part_name, order, value, label) -> {
      case dict.get(part, part_name) {
        Ok(quantity) ->
          case int.compare(quantity, value) {
            o if o == order -> Ok(label)
            _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }
  }
}

fn filter_part(
  part: Part,
  ruleset_map: RulesetMap,
  ruleset_label: String,
) -> Bool {
  case dict.get(ruleset_map, ruleset_label) {
    Ok(ruleset) -> {
      let application =
        list.fold_until(
          ruleset,
          True,
          fn(acc, rule) {
            case apply_rule(part, rule) {
              Ok(label) ->
                case label {
                  Accepted -> list.Stop(True)
                  Rejected -> list.Stop(False)
                  RuleLabel(goto) ->
                    list.Stop(filter_part(part, ruleset_map, goto))
                }
              _ -> list.Continue(acc)
            }
          },
        )

      application
    }

    _ -> panic
  }
}

fn sum_parts(input: List(Part)) -> Int {
  input
  |> list.flat_map(dict.values)
  |> int.sum
}

pub fn pt_1(input: String) {
  input
  |> get_rules_and_parts
  |> fn(rules_and_parts) {
    let #(ruleset_map, parts) = rules_and_parts

    parts
    |> list.filter(filter_part(_, ruleset_map, "in"))
  }
  |> sum_parts
}

fn find_all_accepted_paths(
  rules_map: RulesetMap,
  queue: List(#(List(Rule), String)),
  terminated_paths_accepted: List(List(Rule)),
  terminated_paths_rejected: List(List(Rule)),
) -> #(List(List(Rule)), List(List(Rule))) {
  case queue {
    [#(path, next), ..remaining] -> {
      let assert Ok(rules) = dict.get(rules_map, next)
      let #(
        next_queue,
        next_terminated_paths_accepted,
        next_terminated_paths_rejected,
      ) =
        list.fold(
          rules,
          #(remaining, terminated_paths_accepted, terminated_paths_rejected),
          fn(state, rule) {
            let #(
              remaining,
              terminated_paths_accepted,
              terminated_paths_rejected,
            ) = state
            let next_path = list.append(path, [rule])
            case rule {
              Auto(Rejected) | Inequality(_, _, _, Rejected) -> #(
                remaining,
                terminated_paths_accepted,
                list.append(terminated_paths_rejected, [next_path]),
              )
              Auto(Accepted) | Inequality(_, _, _, Accepted) -> #(
                remaining,
                list.append(terminated_paths_accepted, [next_path]),
                terminated_paths_rejected,
              )
              Auto(RuleLabel(next_label))
              | Inequality(_, _, _, RuleLabel(next_label)) -> #(
                list.append(remaining, [#(next_path, next_label)]),
                terminated_paths_accepted,
                terminated_paths_rejected,
              )
            }
          },
        )

      find_all_accepted_paths(
        rules_map,
        next_queue,
        next_terminated_paths_accepted,
        next_terminated_paths_rejected,
      )
    }
    [] -> #(terminated_paths_accepted, terminated_paths_rejected)
  }
}

fn in_range(range: #(Int, Int), value: Int) -> Bool {
  value > range.0 && value < range.1
}

fn range_contains(source: #(Int, Int), other: #(Int, Int)) -> Bool {
  source.0 <= other.0 && source.1 >= other.1
}

fn range_intersects(range_one: #(Int, Int), range_two: #(Int, Int)) -> Bool {
  { range_two.1 >= range_one.0 && range_two.0 <= range_one.1 }
}

fn range_intersection(source: #(Int, Int), target: #(Int, Int)) -> #(Int, Int) {
  #(int.max(source.0, target.0), int.min(source.1, target.1))
}

fn reduce_range_from_existing(
  existing: List(#(Int, Int)),
  range: #(Int, Int),
) -> #(Int, Int) {
  list.fold(
    existing,
    range,
    fn(next_existing, range) {
      case range_contains(range, next_existing) {
        True -> #(0, 0)
        False ->
          case range_intersects(range, next_existing) {
            True -> range_intersection(range, next_existing)
            False -> range
          }
      }
    },
  )
}

fn reduce_max_part_list(rules_and_parts) {
  let #(ruleset_map, parts) = rules_and_parts
  let accounted_for =
    [#("x", []), #("m", []), #("a", []), #("s", [])]
    |> dict.from_list
  let max_parts =
    [
      #("x", #(0, 4000)),
      #("m", #(0, 4000)),
      #("a", #(0, 4000)),
      #("s", #(0, 4000)),
    ]
    |> dict.from_list

  let #(accepted_paths, rejected_paths) =
    find_all_accepted_paths(ruleset_map, [#([], "in")], [], [])

  let possible =
    list.fold(
      accepted_paths,
      #(0, accounted_for),
      fn(state, path) {
        let #(total_possibilities, accounted_for) = state
        let part_constraints =
          list.fold(
            path,
            max_parts,
            fn(parts, rule) {
              case rule {
                Auto(_) -> parts
                Inequality(part_name, ord, value, _) -> {
                  let assert Ok(current_range) = dict.get(parts, part_name)

                  let next_range = case in_range(current_range, value) {
                    True ->
                      case ord {
                        order.Lt -> #(current_range.0, value - 1)
                        order.Gt -> #(value + 1, current_range.1)
                        _ -> panic
                      }
                    False -> current_range
                  }

                  dict.insert(parts, part_name, next_range)
                }
              }
            },
          )
        let reduced =
          list.fold(
            dict.keys(accounted_for),
            part_constraints,
            fn(reduced, key) {
              let assert Ok(currently_accounted) = dict.get(accounted_for, key)
              let assert Ok(next_range) = dict.get(reduced, key)
              let reduced_range =
                reduce_range_from_existing(currently_accounted, next_range)

              dict.insert(reduced, key, reduced_range)
            },
          )
        io.debug(path)
        io.debug(part_constraints)
        io.debug(#("reduced", reduced))

        let next_possibilities =
          reduced
          |> dict.values()
          |> list.map(fn(x) { int.max(x.1 - x.0, 1) })
          |> io.debug
          |> list.fold(1, int.multiply)
          |> io.debug

        let next_accounted_for =
          common.dict_entries(accounted_for)
          |> list.zip(common.dict_entries(part_constraints))
          |> list.map(fn(zipped) {
            let #(#(key, a), #(_, b)) = zipped
            #(key, list.append(a, [b]))
          })
          |> dict.from_list

        io.debug("")
        #(total_possibilities + next_possibilities, next_accounted_for)
      },
    )
    |> pair.first
}

pub fn pt_2(input: String) {
  let max_possible_combinations = 4000 * 4000 * 4000 * 4000

  io.debug(max_possible_combinations)
  input
  |> get_rules_and_parts
  |> reduce_max_part_list
}
