import gleeunit
import gleeunit/should
import priority_queue
import gleam/int
import gleam/io

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn priority_queue_test() {
  let q =
    priority_queue.new(int.compare)
    |> priority_queue.enqueue(10)
    |> io.debug
    |> priority_queue.enqueue(9)
    |> io.debug
    |> priority_queue.enqueue(8)
    |> io.debug
    |> priority_queue.enqueue(7)
    |> io.debug

  // io.debug(#(q))
  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(q)

  should.equal(el, 7)
  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(next_queue)

  should.equal(el, 8)
  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(next_queue)

  should.equal(el, 9)
  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(next_queue)

  should.equal(el, 10)

  priority_queue.dequeue(next_queue)
  |> should.equal(Error(Nil))

  let next_queue =
    priority_queue.enqueue(next_queue, 1)
    |> priority_queue.enqueue(2)
    |> priority_queue.enqueue(3)

  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(next_queue)
  should.equal(el, 1)
  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(next_queue)
  should.equal(el, 2)

  let assert Ok(#(el, next_queue)) = priority_queue.dequeue(next_queue)
  should.equal(el, 3)

  [10, 2, 9, 1, 100, 3, 8, 4]
  |> priority_queue.from_list(int.compare)
  |> priority_queue.to_list()
  |> io.debug
  |> should.equal([1, 2, 3, 4, 8, 9, 10, 100])

  [10, 2, 9, 1, 100, 3, 8, 4]
  |> priority_queue.from_list(fn(a, b) { int.compare(b, a) })
  |> priority_queue.to_list
  |> io.debug
  |> should.equal([100, 10, 9, 8, 4, 3, 2, 1])
  // priority_queue.dequeue
  // |> should.equal(Ok(#(7)))
}
