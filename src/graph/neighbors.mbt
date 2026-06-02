///|
/// Neighbors of `a` reachable via outgoing edges (for directed) or any edge
/// (for undirected).
///
/// Equivalent to `neighbors_directed(a, Outgoing)`.
pub fn[N, E] Graph::neighbors(self : Graph[N, E], a : NodeId) -> Array[NodeId] {
  self.neighbors_directed(a, Outgoing)
}

///|
/// Neighbors of `a` in the specified direction.
///
/// - Directed, Outgoing: targets of edges from `a`.
/// - Directed, Incoming: sources of edges to `a`.
/// - Undirected: all neighbors (direction is ignored).
///
/// Within each list, neighbors appear in reverse order of edge insertion (most
/// recently added first), matching petgraph.
pub fn[N, E] Graph::neighbors_directed(
  self : Graph[N, E],
  a : NodeId,
  dir : Direction,
) -> Array[NodeId] {
  // Start from the undirected walk state, then for a directed graph restrict to
  // the single requested direction (clear the other head, disable self-loop
  // skipping), mirroring petgraph's `neighbors_directed`.
  let (out0, in0) = match self.nodes.get(a.index()) {
    None => (EdgeId::end(), EdgeId::end())
    Some(n) => (n.next_out, n.next_in)
  }
  let mut next_out = out0
  let mut next_in = in0
  let mut skip_start = a
  if self.is_directed() {
    match dir {
      Outgoing => next_in = EdgeId::end()
      Incoming => next_out = EdgeId::end()
    }
    skip_start = NodeId::end()
  }
  self.walk_neighbors(next_out, next_in, skip_start)
}

///|
/// Neighbors of `a` in either direction (treating the graph as undirected).
///
/// Outgoing neighbors are listed first, then incoming; within each, reverse
/// insertion order. Self-loops are counted once (skipped in the incoming list).
pub fn[N, E] Graph::neighbors_undirected(
  self : Graph[N, E],
  a : NodeId,
) -> Array[NodeId] {
  let (next_out, next_in) = match self.nodes.get(a.index()) {
    None => (EdgeId::end(), EdgeId::end())
    Some(n) => (n.next_out, n.next_in)
  }
  self.walk_neighbors(next_out, next_in, a)
}

///|
/// Shared walk used by the `neighbors*` methods, porting petgraph's
/// `Neighbors::next`: first the outgoing list (yielding targets), then the
/// incoming list (yielding sources), skipping self-loops whose source equals
/// `skip_start`.
fn[N, E] Graph::walk_neighbors(
  self : Graph[N, E],
  next_out : EdgeId,
  next_in : EdgeId,
  skip_start : NodeId,
) -> Array[NodeId] {
  let result : Array[NodeId] = []
  // Outgoing edges: yield the target of each.
  let mut o = next_out
  while self.edges.get(o.index()) is Some(edge) {
    o = edge.next_out
    result.push(edge.dst)
  }
  // Incoming edges: yield the source of each, skipping self-loops.
  let mut i = next_in
  while self.edges.get(i.index()) is Some(edge) {
    i = edge.next_in
    if edge.src != skip_start {
      result.push(edge.src)
    }
  }
  result
}

///|
/// All edges of `a` in the specified direction.
///
/// - Directed, Outgoing: edges from `a`.
/// - Directed, Incoming: edges to `a`.
/// - Undirected: all edges connected to `a` (both lists; self-loops once).
///
/// Within each list, reverse insertion order, matching petgraph.
pub fn[N, E] Graph::edges_directed(
  self : Graph[N, E],
  a : NodeId,
  dir : Direction,
) -> Array[EdgeId] {
  let (next_out, next_in) = match self.nodes.get(a.index()) {
    None => (EdgeId::end(), EdgeId::end())
    Some(n) => (n.next_out, n.next_in)
  }
  let result : Array[EdgeId] = []
  let directed = self.is_directed()
  // iterate_over: Directed -> only `dir`; Undirected -> both lists.
  let do_out = !directed || dir == Outgoing
  let do_in = !directed || dir == Incoming
  if do_out {
    let mut o = next_out
    while self.edges.get(o.index()) is Some(edge) {
      let cur = o
      o = edge.next_out
      result.push(cur)
    }
  }
  if do_in {
    let mut i = next_in
    while self.edges.get(i.index()) is Some(edge) {
      let cur = i
      i = edge.next_in
      // In the undirected "both" case, skip self-loops in the incoming list so
      // they are not iterated twice.
      if !directed && edge.src == a {
        continue
      }
      result.push(cur)
    }
  }
  result
}

///|
/// Nodes that are sources (`Incoming`) or sinks (`Outgoing`) of the graph: nodes
/// with no edges in the given direction.
///
/// For an undirected graph, both queries return the nodes with no edges at all.
/// Listed in ascending index order. O(|V|).
pub fn[N, E] Graph::externals(
  self : Graph[N, E],
  dir : Direction,
) -> Array[NodeId] {
  let result : Array[NodeId] = []
  let directed = self.is_directed()
  for i in 0..<self.nodes.length() {
    let node = self.nodes[i]
    let in_dir = node.next(dir)
    let in_other = node.next(dir.opposite())
    // A node is external if it has no edge in `dir`, and (for undirected) also
    // none in the opposite direction.
    if in_dir.is_end() && (directed || in_other.is_end()) {
      result.push(NodeId::new(i))
    }
  }
  result
}
