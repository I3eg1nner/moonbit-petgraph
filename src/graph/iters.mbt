///|
/// All node weights, in node index order.
///
/// Returns a fresh, lazy single-use `Iter[N]`. Port of petgraph's
/// `node_weights` (the `_mut` variant has no MoonBit counterpart: use
/// `set_node_weight`).
pub fn[N, E] Graph::node_weights(self : Graph[N, E]) -> Iter[N] {
  self.nodes.iter().map(node => node.weight)
}

///|
/// All edge weights, in edge index order.
///
/// Returns a fresh, lazy single-use `Iter[E]`. Port of petgraph's
/// `edge_weights` (see `set_edge_weight` for the `_mut` variant).
pub fn[N, E] Graph::edge_weights(self : Graph[N, E]) -> Iter[E] {
  self.edges.iter().map(edge => edge.weight)
}

///|
/// Extend the graph from a list of `(source, target, weight)` edges.
///
/// Nodes are inserted automatically so that every referenced index exists;
/// their weights are `N::default()`, matching petgraph's `N: Default` bound on
/// `extend_with_edges`. Edges are added in the given order, so the usual
/// reverse-insertion adjacency ordering applies.
pub fn[N : Default, E] Graph::extend_with_edges(
  self : Graph[N, E],
  edges : Array[(NodeId, NodeId, E)],
) -> Unit {
  for elt in edges {
    let (source, target, weight) = elt
    let nx = if source > target { source } else { target }
    while nx.index() >= self.node_count() {
      let _ = self.add_node(N::default())
    }
    let _ = self.add_edge(source, target, weight)
  }
}

///|
/// Data structure internals: the first edge of `a` in direction `dir`, i.e. the
/// head of that adjacency list, or `None` if the node has no such edge (or does
/// not exist).
pub fn[N, E] Graph::first_edge(
  self : Graph[N, E],
  a : NodeId,
  dir : Direction,
) -> EdgeId? {
  guard self.nodes.get(a.index()) is Some(node) else { return None }
  let edix = node.next(dir)
  if edix.is_end() {
    None
  } else {
    Some(edix)
  }
}

///|
/// Data structure internals: the next edge after `e` in direction `dir`, or
/// `None` at the end of the list (or if `e` does not exist).
///
/// Together with `first_edge` this walks the intrusive adjacency lists:
/// `Outgoing` walks the source's outgoing list, `Incoming` the target's
/// incoming list.
pub fn[N, E] Graph::next_edge(
  self : Graph[N, E],
  e : EdgeId,
  dir : Direction,
) -> EdgeId? {
  guard self.edges.get(e.index()) is Some(edge) else { return None }
  let edix = edge.next(dir)
  if edix.is_end() {
    None
  } else {
    Some(edix)
  }
}

///|
/// Decompose the graph into its node weights and its edges.
///
/// Returns `(node_weights, edges)` where `node_weights[i]` is the weight of
/// node `i` and each edge is `(source, target, weight)` in edge index order.
///
/// Adapted from petgraph's `into_nodes_edges`, which returns the raw
/// `Vec<Node>` / `Vec<Edge>` including the intrusive links; those types are
/// private here, so the adjacency links are dropped and the endpoints are
/// reported explicitly. Unlike Rust this does not consume `self`: the graph is
/// left untouched and fresh arrays are returned.
pub fn[N, E] Graph::into_nodes_edges(
  self : Graph[N, E],
) -> (Array[N], Array[(NodeId, NodeId, E)]) {
  let nodes = [ for node in self.nodes => node.weight ]
  let edges = [ for edge in self.edges => (edge.src, edge.dst, edge.weight) ]
  (nodes, edges)
}
