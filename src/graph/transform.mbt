///|
/// Create a new `Graph` by mapping node and edge weights to new values.
///
/// The resulting graph has the same structure, the same directedness and the
/// same node and edge indices as `self`; only the weights change. The
/// adjacency links are copied verbatim, so no relinking work is done.
///
/// `node_map` is called as `node_map(node_id, weight)` for every node in index
/// order, then `edge_map(edge_id, weight)` for every edge in index order.
///
/// Port of petgraph's `Graph::map`. Rust hands the closures a borrow of the
/// weight; MoonBit passes the weight itself (values are shared by reference,
/// so this is the same thing for boxed weights).
pub fn[N, E, N2, E2] Graph::map(
  self : Graph[N, E],
  node_map : (NodeId, N) -> N2,
  edge_map : (EdgeId, E) -> E2,
) -> Graph[N2, E2] {
  let g : Graph[N2, E2] = { nodes: [], edges: [], ty: self.ty }
  for i, node in self.nodes {
    g.nodes.push({
      weight: node_map(NodeId::new(i), node.weight),
      next_out: node.next_out,
      next_in: node.next_in,
    })
  }
  for i, edge in self.edges {
    g.edges.push({
      weight: edge_map(EdgeId::new(i), edge.weight),
      next_out: edge.next_out,
      next_in: edge.next_in,
      src: edge.src,
      dst: edge.dst,
    })
  }
  g
}

///|
/// Create a new `Graph` by mapping nodes and edges, dropping any that map to
/// `None`.
///
/// Nodes are mapped first with `node_map`; `edge_map` is then called only for
/// the edges that still have both endpoints. Surviving nodes and edges are
/// renumbered densely in their original relative order, so if no node is
/// dropped the node indices stay compatible with `self`, and if nothing at all
/// is dropped the whole index space is preserved.
///
/// The directedness of `self` is preserved. Port of petgraph's
/// `Graph::filter_map`.
pub fn[N, E, N2, E2] Graph::filter_map(
  self : Graph[N, E],
  node_map : (NodeId, N) -> N2?,
  edge_map : (EdgeId, E) -> E2?,
) -> Graph[N2, E2] {
  let g : Graph[N2, E2] = { nodes: [], edges: [], ty: self.ty }
  // Mapping from old node index to new node index; `end` represents removed.
  let node_index_map = Array::make(self.nodes.length(), NodeId::end())
  for i, node in self.nodes {
    if node_map(NodeId::new(i), node.weight) is Some(nw) {
      node_index_map[i] = g.add_node(nw)
    }
  }
  for i, edge in self.edges {
    // Skip the edge if either endpoint was removed.
    let source = node_index_map[edge.src.index()]
    let target = node_index_map[edge.dst.index()]
    if source != NodeId::end() &&
      target != NodeId::end() &&
      edge_map(EdgeId::new(i), edge.weight) is Some(ew) {
      let _ = g.add_edge(source, target, ew)
    }
  }
  g
}
