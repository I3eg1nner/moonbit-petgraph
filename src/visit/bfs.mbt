///|
/// A breadth-first search (BFS) of a graph.
///
/// The traversal starts at a given node and only reaches nodes reachable from
/// it. Not recursive: an explicit FIFO `queue` is used.
pub struct Bfs {
  /// The queue of nodes to visit.
  queue : @deque.Deque[@graph.NodeId]
  /// The set of discovered (already enqueued) nodes.
  discovered : VisitMap
}

///|
/// Create a new `Bfs`, marking `start` discovered and enqueuing it.
pub fn[G : @graph.NeighborSource] Bfs::new(
  graph : G,
  start : @graph.NodeId,
) -> Bfs {
  let discovered = VisitMap::new(graph.node_count())
  discovered.visit(start) |> ignore
  let queue = @deque.Deque([])
  queue.push_back(start)
  { queue, discovered }
}

///|
/// Return the next node in the BFS order, or `None` when the traversal is done.
pub fn[G : @graph.NeighborSource] Bfs::next(
  self : Bfs,
  graph : G,
) -> @graph.NodeId? {
  match self.queue.pop_front() {
    Some(node) => {
      for succ in graph.neighbors_directed(node, Outgoing) {
        if self.discovered.visit(succ) {
          self.queue.push_back(succ)
        }
      }
      Some(node)
    }
    None => None
  }
}
