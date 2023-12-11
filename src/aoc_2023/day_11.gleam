import gleam/int
import gleam/list
import common
import gleam/result
import gleam/pair

type Universe =
  List(List(String))

fn get_empty_cols_and_rows(universe: Universe) -> #(List(Int), List(Int)) {
  let common.Coord(x, _) = common.two_d_array_dims(universe)
  let empty_cols =
    common.array_with_length(x)
    |> list.filter(fn(col_idx) {
      universe
      |> list.map(fn(row) {
        list.at(row, col_idx)
        |> common.unwrap_expect("unexpected list idx out of bounds")
      })
      |> list.all(fn(x) { x == "." })
    })

  let empty_rows =
    universe
    |> list.index_map(fn(idx, row) { #(idx, row) })
    |> list.filter(fn(row) {
      row.1
      |> list.all(fn(x) { x == "." })
    })
    |> list.map(pair.first)

  #(empty_cols, empty_rows)
}

fn extract_galaxy_coords(universe: Universe) -> List(common.Coord) {
  universe
  |> list.index_fold(
    [],
    fn(coords, row, row_idx) {
      let next_coords =
        row
        |> list.index_map(fn(col_idx, el) {
          case el == "#" {
            True -> Ok(common.Coord(col_idx, row_idx))
            False -> Error(Nil)
          }
        })
        |> result.values
      [
        next_coords
        |> list.reverse,
        ..coords
      ]
    },
  )
  |> list.flat_map(common.identity)
  |> list.reverse
}

fn manhattan_dist(coord_a: common.Coord, coord_b: common.Coord) -> Int {
  int.absolute_value(coord_a.x - coord_b.x) + int.absolute_value(
    coord_a.y - coord_b.y,
  )
}

fn multipliers(empties: List(Int), initial: Int, multiplier: Int) -> Int {
  empties
  |> list.filter(fn(col_number) { col_number < initial })
  |> list.length()
  |> int.multiply(multiplier - 1)
  |> int.add(initial)
}

fn compute_pairwise_distances_with_expansion(
  galaxies: List(common.Coord),
  multiplier: Int,
  empty_cols_and_rows: #(List(Int), List(Int)),
) {
  let #(empty_cols, empty_rows) = empty_cols_and_rows

  galaxies
  |> list.map(fn(galaxy) {
    let common.Coord(galaxy_x, galaxy_y) = galaxy
    let next_x = multipliers(empty_cols, galaxy_x, multiplier)
    let next_y = multipliers(empty_rows, galaxy_y, multiplier)

    common.Coord(next_x, next_y)
  })
  |> list.combination_pairs
  |> list.map(fn(pair) {
    let #(g_a, g_b) = pair
    manhattan_dist(g_a, g_b)
  })
}

fn compute_through_space_time(universe: Universe, expansion_multiplier: Int) {
  let cols_and_rows = get_empty_cols_and_rows(universe)
  let galaxies = extract_galaxy_coords(universe)
  compute_pairwise_distances_with_expansion(
    galaxies,
    expansion_multiplier,
    cols_and_rows,
  )
}

pub fn pt_1(input: String) {
  input
  |> common.parse_string_into_grid
  |> compute_through_space_time(2)
  |> int.sum
}

pub fn pt_2(input: String) {
  input
  |> common.parse_string_into_grid
  |> compute_through_space_time(1_000_000)
  |> int.sum
}
