///|
/// Visit nodes of a graph in depth-first order, emitting each node in preorder
/// (when it is first discovered).
///
/// The traversal starts at a given node and only reaches nodes reachable from
/// it. `Dfs` does not borrow the graph; the graph is passed to each `next`
/// call, so it can be traversed while still mutating it.
///
/// Not recursive: an explicit `stack` is used.
pub struct Dfs {
  /// The stack of nodes to visit.
  stack : Array[@graph.NodeId]
  /// The set of discovered nodes.
  discovered : VisitMap
}

///|
/// Create a new `Dfs`, seeding the stack with `start`.
///
/// # Example
/// ```mbt check
/// test {
///   // A path 0 -> 1 -> 2.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
///   let dfs = @visit.Dfs::new(g, @graph.NodeId::new(0))
///   let order = []
///   while dfs.next(g) is Some(n) {
///     order.push(n.index())
///   }
///   debug_inspect(order, content="[0, 1, 2]")
/// }
/// ```
pub fn[G : @graph.NeighborSource] Dfs::new(
  graph : G,
  start : @graph.NodeId,
) -> Dfs {
  let dfs = Dfs::empty(graph)
  dfs.move_to(start)
  dfs
}

///|
/// Create a new `Dfs` with an empty stack and a fresh visit map sized for the
/// graph.
pub fn[G : @graph.NeighborSource] Dfs::empty(graph : G) -> Dfs {
  { stack: [], discovered: VisitMap::new(graph.node_count()) }
}

///|
/// Clear the visit state: empty the stack and reset the discovered map.
pub fn Dfs::reset(self : Dfs) -> Unit {
  self.discovered.reset()
  self.stack.clear()
}

///|
/// Keep the discovered map, but clear the stack and restart the search from
/// `start`.
pub fn Dfs::move_to(self : Dfs, start : @graph.NodeId) -> Unit {
  self.stack.clear()
  self.stack.push(start)
}

///|
/// Return the next node in the DFS preorder, or `None` when the traversal is
/// done.
pub fn[G : @graph.NeighborSource] Dfs::next(
  self : Dfs,
  graph : G,
) -> @graph.NodeId? {
  while self.stack.pop() is Some(node) {
    if self.discovered.visit(node) {
      for succ in graph.neighbors_directed(node, Outgoing) {
        if !self.discovered.is_visited(succ) {
          self.stack.push(succ)
        }
      }
      return Some(node)
    }
  }
  None
}
