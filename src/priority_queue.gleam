import gleam/queue

pub opaque type PriorityQueue(a) {
  PriorityQueue(heap: queue.Queue(a))
}

pub fn new() -> PriorityQueue(a) {
  PriorityQueue(queue.new())
}

pub fn enqueue(q: PriorityQueue(a), el: a) -> PriorityQueue(a) {
  let next_heap = queue.push_back(q.heap, el)
  heapify_up(PriorityQueue(next_heap))
}

pub fn dequeue(q: PriorityQueue(a)) -> Result(#(a, PriorityQueue(a)), Nil) {
  case queue.pop_front(q.heap) {
    Error(_) -> Error(Nil)
    Ok(#(el, next_heap)) -> {
      case queue.pop_back(next_heap) {
        Error(_) -> Ok(#(el, PriorityQueue(queue.new())))
        Ok(#(back, next_heap)) -> {
          let next_heap = queue.push_front(next_heap, back)
          let next = heapify_down(PriorityQueue(next_heap))
          Ok(#(el, next))
        }
      }
    }
  }
}

fn heapify_up(q: PriorityQueue(a)) -> PriorityQueue(a) {
  todo
}

fn heapify_down(q: PriorityQueue(a)) -> PriorityQueue(a) {
  todo
}
