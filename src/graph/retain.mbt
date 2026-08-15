///|
/// Keep all nodes for which `visit` returns `true`; remove the others.
///
/// `visit` receives the graph itself plus the node id, so weights can be
/// inspected and updated while filtering (petgraph passes a `Frozen` proxy for
/// the same purpose). Do **not** add or remove nodes/edges from inside `visit`:
/// the traversal relies on the swap-remove index invariants below.
///
/// Nodes are visited in *descending* index order, exactly as petgraph does
/// (`self.node_indices().rev()`). That is what makes `remove_node`'s
/// swap-remove safe here: when index `i` is removed, the node currently in the
/// last slot moves into slot `i`, and that node has already been visited (it
/// came from an index `> i`), so it is never visited twice. Conversely, slot
/// `i` always still holds the original node `i` when it is visited.
///
/// Removing a node also removes all of its incident edges.
pub fn[N, E] Graph::retain_nodes(
  self : Graph[N, E],
  visit : (Graph[N, E], NodeId) -> Bool,
) -> Unit {
  // The index range is fixed up-front, like petgraph's `node_indices().rev()`.
  for i = self.node_count() - 1; i >= 0; i = i - 1 {
    let index = NodeId::new(i)
    if !visit(self, index) {
      guard self.remove_node(index) is Some(_) else {
        abort("Graph::retain_nodes: node index out of bounds")
      }
    }
  }
}

///|
/// Keep all edges for which `visit` returns `true`; remove the others.
///
/// `visit` receives the graph itself plus the edge id, so weights can be
/// inspected and updated while filtering (petgraph passes a `Frozen` proxy).
/// Do **not** add or remove nodes/edges from inside `visit`.
///
/// Edges are visited in *descending* index order, exactly as petgraph does
/// (`self.edge_indices().rev()`), which keeps `remove_edge`'s swap-remove
/// correct: the edge swapped into slot `i` always comes from a higher index
/// that has already been visited, and slot `i` always still holds the original
/// edge `i` when it is visited.
pub fn[N, E] Graph::retain_edges(
  self : Graph[N, E],
  visit : (Graph[N, E], EdgeId) -> Bool,
) -> Unit {
  // The index range is fixed up-front, like petgraph's `edge_indices().rev()`.
  for i = self.edge_count() - 1; i >= 0; i = i - 1 {
    let index = EdgeId::new(i)
    if !visit(self, index) {
      guard self.remove_edge(index) is Some(_) else {
        abort("Graph::retain_edges: edge index out of bounds")
      }
    }
  }
}
