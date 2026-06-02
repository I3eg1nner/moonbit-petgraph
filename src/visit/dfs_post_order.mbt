///|
/// Visit nodes in depth-first order, emitting each node in postorder (after all
/// of its descendants have been emitted).
///
/// The traversal starts at a given node and only reaches nodes reachable from
/// it. Not recursive: an explicit `stack` plus `discovered`/`finished` maps are
/// used.
pub struct DfsPostOrder {
  /// The stack of nodes to visit.
  stack : Array[@graph.NodeId]
  /// The set of discovered nodes.
  discovered : VisitMap
  /// The set of finished (emitted) nodes.
  finished : VisitMap
}

///|
/// Create a new `DfsPostOrder`, seeding the stack with `start`.
pub fn[G : @graph.NeighborSource] DfsPostOrder::new(
  graph : G,
  start : @graph.NodeId,
) -> DfsPostOrder {
  let dfs = DfsPostOrder::empty(graph)
  dfs.move_to(start)
  dfs
}

///|
/// Create a new `DfsPostOrder` with an empty stack and fresh visit maps.
pub fn[G : @graph.NeighborSource] DfsPostOrder::empty(
  graph : G,
) -> DfsPostOrder {
  let n = graph.node_count()
  { stack: [], discovered: VisitMap::new(n), finished: VisitMap::new(n) }
}

///|
/// Clear the visit state: empty the stack and reset both maps.
pub fn DfsPostOrder::reset(self : DfsPostOrder) -> Unit {
  self.discovered.reset()
  self.finished.reset()
  self.stack.clear()
}

///|
/// Keep the discovered and finished maps, but clear the stack and restart from
/// `start`.
pub fn DfsPostOrder::move_to(
  self : DfsPostOrder,
  start : @graph.NodeId,
) -> Unit {
  self.stack.clear()
  self.stack.push(start)
}

///|
/// Return the next node in the DFS postorder, or `None` when the traversal is
/// done.
pub fn[G : @graph.NeighborSource] DfsPostOrder::next(
  self : DfsPostOrder,
  graph : G,
) -> @graph.NodeId? {
  while self.stack.last() is Some(nx) {
    if self.discovered.visit(nx) {
      // First time visiting `nx`: push its neighbors, keep `nx` on the stack.
      for succ in graph.neighbors_directed(nx, Outgoing) {
        if !self.discovered.is_visited(succ) {
          self.stack.push(succ)
        }
      }
    } else {
      self.stack.pop() |> ignore
      if self.finished.visit(nx) {
        // Second time: all reachable descendants have been finished.
        return Some(nx)
      }
    }
  }
  None
}
