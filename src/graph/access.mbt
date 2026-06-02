///|
/// Access the weight of node `a`, or `None` if it doesn't exist.
pub fn[N, E] Graph::node_weight(self : Graph[N, E], a : NodeId) -> N? {
  self.nodes.get(a.index()).map(node => node.weight)
}

///|
/// Access the weight of edge `e`, or `None` if it doesn't exist.
pub fn[N, E] Graph::edge_weight(self : Graph[N, E], e : EdgeId) -> E? {
  self.edges.get(e.index()).map(edge => edge.weight)
}

///|
/// Set the weight of edge `e`. Does nothing if `e` is out of bounds.
///
/// MoonBit replacement for petgraph's `edge_weight_mut`.
pub fn[N, E] Graph::set_edge_weight(
  self : Graph[N, E],
  e : EdgeId,
  weight : E,
) -> Unit {
  if self.edges.get(e.index()) is Some(edge) {
    edge.weight = weight
  }
}

///|
/// The source and target nodes of edge `e`, or `None` if it doesn't exist.
pub fn[N, E] Graph::edge_endpoints(
  self : Graph[N, E],
  e : EdgeId,
) -> (NodeId, NodeId)? {
  self.edges.get(e.index()).map(edge => (edge.src, edge.dst))
}

///|
/// Look up an edge from `a` to `b`.
///
/// For a directed graph only the outgoing list of `a` is searched; for an
/// undirected graph both directions are searched (equivalent to
/// `find_edge_undirected`). O(e').
pub fn[N, E] Graph::find_edge(
  self : Graph[N, E],
  a : NodeId,
  b : NodeId,
) -> EdgeId? {
  if !self.is_directed() {
    self.find_edge_undirected(a, b).map(pair => pair.0)
  } else {
    guard self.nodes.get(a.index()) is Some(node) else { return None }
    let mut edix = node.next_out
    while self.edges.get(edix.index()) is Some(edge) {
      if edge.dst == b {
        return Some(edix)
      }
      edix = edge.next_out
    }
    None
  }
}

///|
/// Look up an edge between `a` and `b` in either direction.
///
/// Returns the edge id and its directionality (`Outgoing` means `a -> b`,
/// `Incoming` means `b -> a`), or `None`. O(e').
pub fn[N, E] Graph::find_edge_undirected(
  self : Graph[N, E],
  a : NodeId,
  b : NodeId,
) -> (EdgeId, Direction)? {
  guard self.nodes.get(a.index()) is Some(node) else { return None }
  for d in directions {
    let mut edix = node.next(d)
    while self.edges.get(edix.index()) is Some(edge) {
      // The "other" endpoint, opposite to the list direction `d`.
      let other = edge.node(d.opposite())
      if other == b {
        return Some((edix, d))
      }
      edix = edge.next(d)
    }
  }
  None
}

///|
/// Whether there is an edge from `a` to `b` (per `find_edge` semantics).
pub fn[N, E] Graph::contains_edge(
  self : Graph[N, E],
  a : NodeId,
  b : NodeId,
) -> Bool {
  self.find_edge(a, b) is Some(_)
}

///|
/// All node identifiers, in index order `0 .. node_count-1`, as a fresh lazy
/// single-use `Iter[NodeId]`.
pub fn[N, E] Graph::node_ids(self : Graph[N, E]) -> Iter[NodeId] {
  let mut i = 0
  Iter::new(fn() {
    if i < self.nodes.length() {
      let cur = i
      i = i + 1
      Some(NodeId::new(cur))
    } else {
      None
    }
  })
}

///|
/// All edge identifiers, in index order `0 .. edge_count-1`, as a fresh lazy
/// single-use `Iter[EdgeId]`.
pub fn[N, E] Graph::edge_ids(self : Graph[N, E]) -> Iter[EdgeId] {
  let mut i = 0
  Iter::new(fn() {
    if i < self.edges.length() {
      let cur = i
      i = i + 1
      Some(EdgeId::new(cur))
    } else {
      None
    }
  })
}
