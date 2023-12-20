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

pub type Pulse {
  High
  Low
}

pub type Gate {
  PassThrough
  FlipFlop(state: Bool)
  Conjunction(state: dict.Dict(String, Pulse))
}

pub type ModuleState =
  dict.Dict(String, Module)

pub type Module {
  Module(name: String, gate: Gate, connections: List(String))
}

pub type Input {
  Input(from: String, to: String, pulse: Pulse)
}

fn pulse_of_bool(input: Bool) -> Pulse {
  case input {
    True -> High
    False -> Low
  }
}

fn bool_of_pulse(input: Pulse) -> Bool {
  case input {
    High -> True
    Low -> False
  }
}

fn pulse_invert(input: Pulse) -> Pulse {
  case input {
    High -> Low
    Low -> High
  }
}

fn parse_gate(input: String) -> Gate {
  case input {
    "%" -> FlipFlop(False)
    "&" -> Conjunction(dict.new())
  }
}

fn parse_gate_and_name(input: String) -> #(String, Gate) {
  let assert Ok(gate_rex) = regex.from_string("([%|&])?(.+)")

  case regex.scan(gate_rex, input) {
    [regex.Match(_, [option.Some(gate), option.Some(name)])] -> #(
      name,
      parse_gate(gate),
    )
    [regex.Match(_, [option.None, option.Some(name)])] -> #(name, PassThrough)
  }
}

fn parse_module(input: String) -> Module {
  case string.split_once(input, " -> ") {
    Ok(#(gate_and_name, connections)) -> {
      let #(name, gate) = parse_gate_and_name(gate_and_name)
      let connections =
        string.split(connections, ",")
        |> list.map(string.trim)
      Module(name, gate, connections)
    }
    Error(_) -> panic
  }
}

fn parse_modules(input: String) -> List(Module) {
  input
  |> string.split("\n")
  |> list.map(parse_module)
}

fn initialize_conjunction_state(
  modules: List(Module),
  name: String,
  state: dict.Dict(String, Pulse),
) {
  list.fold(
    modules,
    state,
    fn(acc, other_module) {
      case other_module {
        Module(connection_name, _, connections) -> {
          case list.any(connections, fn(con) { con == name }) {
            True -> dict.insert(acc, connection_name, Low)
            False -> acc
          }
        }
      }
    },
  )
}

fn add_missing_entries_from_connections(modules: ModuleState) -> ModuleState {
  common.dict_entries(modules)
  |> list.fold(
    modules,
    fn(acc, module_entry) {
      case module_entry {
        #(_, Module(_, _, connections)) -> {
          list.fold(
            connections,
            acc,
            fn(n_acc, connection) {
              case dict.get(n_acc, connection) {
                Ok(_) -> n_acc
                Error(Nil) ->
                  dict.insert(
                    n_acc,
                    connection,
                    Module(connection, PassThrough, []),
                  )
              }
            },
          )
        }
      }
    },
  )
}

fn initialize_modules(modules: List(Module)) -> ModuleState {
  modules
  |> list.fold(
    dict.new(),
    fn(acc, module) {
      case module {
        Module(name, Conjunction(state), connections) -> {
          let next_state = initialize_conjunction_state(modules, name, state)
          dict.insert(
            acc,
            name,
            Module(name, Conjunction(next_state), connections),
          )
        }
        Module(name, _, _) -> {
          dict.insert(acc, name, module)
        }
      }
    },
  )
  |> add_missing_entries_from_connections
}

fn evaluate_passthrough(
  modules: ModuleState,
  module: Module,
  pulse: Pulse,
) -> #(List(Input), ModuleState) {
  let inputs =
    module.connections
    |> list.map(fn(connection) { Input(module.name, connection, pulse) })

  #(inputs, modules)
}

fn evaluate_flip_flop(
  modules: ModuleState,
  module: Module,
  pulse: Pulse,
) -> #(List(Input), ModuleState) {
  case module {
    Module(name, FlipFlop(state), connections) -> {
      case pulse {
        High -> #([], modules)
        Low -> {
          let pulse_to_send =
            pulse_of_bool(state)
            |> pulse_invert

          let inputs =
            list.map(
              connections,
              fn(connection) { Input(name, connection, pulse_to_send) },
            )

          let next_modules =
            dict.insert(
              modules,
              name,
              Module(name, FlipFlop(!state), connections),
            )

          #(inputs, next_modules)
        }
      }
    }
    _ -> common.unreachable("expected flipflop gate")
  }
}

fn evaluate_conjunction(
  modules: ModuleState,
  module: Module,
  from: String,
  pulse: Pulse,
) -> #(List(Input), ModuleState) {
  case module {
    Module(name, Conjunction(state), connections) -> {
      let next_module_state = dict.insert(state, from, pulse)
      let next_pulse =
        list.all(dict.values(next_module_state), bool_of_pulse)
        |> pulse_of_bool
        |> pulse_invert

      let inputs =
        list.map(
          connections,
          fn(connection) { Input(name, connection, next_pulse) },
        )
      let next_state =
        dict.insert(
          modules,
          name,
          Module(name, Conjunction(next_module_state), connections),
        )
      #(inputs, next_state)
    }
    _ -> common.unreachable("expected conjunction gate")
  }
}

fn evaluate_from_input(
  modules: ModuleState,
  module: Module,
  from: String,
  pulse: Pulse,
) -> #(List(Input), ModuleState) {
  case module {
    Module(_, PassThrough, _) -> evaluate_passthrough(modules, module, pulse)
    Module(_, FlipFlop(_), _) -> evaluate_flip_flop(modules, module, pulse)
    Module(_, Conjunction(_), _) ->
      evaluate_conjunction(modules, module, from, pulse)
  }
}

fn evaluate_circuit_inner(
  modules: ModuleState,
  input_queue: queue.Queue(Input),
  evaluated_inputs: List(Input),
) -> #(List(Input), ModuleState) {
  case queue.pop_back(input_queue) {
    Ok(#(next_input, remaining_inputs)) -> {
      let Input(from, to, pulse) = next_input
      let assert Ok(module) = dict.get(modules, to)
      let #(next_inputs, next_state) =
        evaluate_from_input(modules, module, from, pulse)

      let next_queue =
        list.fold(
          next_inputs,
          remaining_inputs,
          fn(q, input) { queue.push_front(q, input) },
        )
      let next_evaluated_inputs = list.append(evaluated_inputs, [next_input])

      evaluate_circuit_inner(next_state, next_queue, next_evaluated_inputs)
    }
    Error(Nil) -> #(evaluated_inputs, modules)
  }
}

fn evaluate_circuit(
  modules: ModuleState,
  button_press: Input,
) -> #(List(Input), ModuleState) {
  let #(next_inputs, next_modules) =
    evaluate_circuit_inner(modules, queue.from_list([button_press]), [])

  #(next_inputs, next_modules)
}

fn evaluate_circuit_from_button_press(
  modules: ModuleState,
) -> #(List(Input), ModuleState) {
  let #(next_inputs, next_modules) =
    evaluate_circuit_inner(
      modules,
      queue.from_list([Input("button", "broadcaster", Low)]),
      [],
    )

  #(next_inputs, next_modules)
}

fn evaluate_circuit_from_known_inputs(
  modules: ModuleState,
  initial_inputs: List(Input),
) -> List(Input) {
  let #(inputs, _final_module_state) =
    list.fold(
      initial_inputs,
      #([], modules),
      fn(acc, button_press) {
        let #(last_inputs, modules) = acc
        let #(next_inputs, next_modules) =
          evaluate_circuit(modules, button_press)

        #(list.append(last_inputs, next_inputs), next_modules)
      },
    )

  inputs
}

fn compute_pulse_answer(pulses: List(Input)) -> Int {
  let partitioned_pulses =
    pulses
    |> list.partition(fn(input) {
      case input {
        Input(_, _, Low) -> True
        _ -> False
      }
    })
  let #(low, high) = partitioned_pulses

  list.length(low) * list.length(high)
}

fn find_first_rx_low_pulse(
  modules: ModuleState,
  button_presses: Int,
  state: dict.Dict(String, Int),
) -> Int {
  let #(next_pulses, next_modules) = evaluate_circuit_from_button_press(modules)
  io.print("button press: " <> string.inspect(button_presses) <> "\r")
  let next_state =
    list.fold(
      next_pulses,
      state,
      fn(next_state, input) {
        let Input(_, to, pulse) = input
        case to, pulse {
          "cl", Low | "lb", Low | "nj", Low | "rp", Low -> {
            io.debug(#(
              to <> " emitted low at ",
              button_presses,
              " button presses",
            ))

            case dict.get(next_state, to) {
              Ok(_) -> panic
              Error(Nil) -> dict.insert(next_state, to, button_presses)
            }
          }
          _, _ -> next_state
        }
      },
    )
  case dict.size(next_state) {
    4 -> {
      dict.values(next_state)
      |> list.fold(1, fn(a, b) { arithmetics.lcm(a, b) })
    }
    _ -> find_first_rx_low_pulse(next_modules, button_presses + 1, next_state)
  }
}

pub fn pt_1(input: String) {
  input
  |> parse_modules
  |> initialize_modules
  |> evaluate_circuit_from_known_inputs(list.repeat(
    Input("button", "broadcaster", Low),
    1000,
  ))
  |> compute_pulse_answer
}

pub fn pt_2(input: String) {
  input
  |> parse_modules
  |> initialize_modules
  |> find_first_rx_low_pulse(1, dict.new())
}
