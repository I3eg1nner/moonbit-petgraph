///|
/// A topological-order traversal of a graph (Kahn-style).
///
/// `Topo` only visits nodes that are not part of a cycle, i.e. the nodes of a
/// true DAG. Nodes stuck in a cycle (or reachable only through one) are never
/// yielded, matching petgraph. To detect whether a graph is acyclic, run the
/// whole traversal and check that every node was yielded.
pub struct Topo {
  /// Nodes whose incoming edges have all been ordered, ready to visit.
  tovisit : Array[@graph.NodeId]
  /// The set of already-ordered (emitted) nodes.
  ordered : VisitMap
}

///|
/// Create a new `Topo`, seeding the to-visit list with every node that has no
/// incoming edges.
pub fn[G : @graph.NeighborSource] Topo::new(graph : G) -> Topo {
  let topo = Topo::empty(graph)
  topo.extend_with_initials(graph)
  topo
}

///|
/// Create a new `Topo` with an empty to-visit list and a fresh ordered map.
pub fn[G : @graph.NeighborSource] Topo::empty(graph : G) -> Topo {
  { tovisit: [], ordered: VisitMap::new(graph.node_count()) }
}

///|
/// Add all initial nodes (those without incoming edges) to the to-visit list.
fn[G : @graph.NeighborSource] Topo::extend_with_initials(
  self : Topo,
  graph : G,
) -> Unit {
  for a in graph.node_ids() {
    if graph.neighbors_directed(a, Incoming).is_empty() {
      self.tovisit.push(a)
    }
  }
}

///|
/// Clear the ordered state and re-seed the to-visit list with initial nodes.
pub fn[G : @graph.NeighborSource] Topo::reset(self : Topo, graph : G) -> Unit {
  self.ordered.reset()
  self.tovisit.clear()
  self.extend_with_initials(graph)
}

///|
/// Return the next node in topological order, or `None` when no more nodes can
/// be ordered (the traversal is at its end; remaining nodes, if any, lie on
/// cycles).
pub fn[G : @graph.NeighborSource] Topo::next(
  self : Topo,
  graph : G,
) -> @graph.NodeId? {
  // Take an unvisited element and find which of its neighbors are next.
  while self.tovisit.pop() is Some(nix) {
    if self.ordered.is_visited(nix) {
      continue
    }
    self.ordered.visit(nix) |> ignore
    for neigh in graph.neighbors_directed(nix, Outgoing) {
      // A neighbor becomes ready once all of *its* incoming edges come from
      // already-ordered nodes.
      let mut all_ordered = true
      for b in graph.neighbors_directed(neigh, Incoming) {
        if !self.ordered.is_visited(b) {
          all_ordered = false
          break
        }
      }
      if all_ordered {
        self.tovisit.push(neigh)
      }
    }
    return Some(nix)
  }
  None
}
