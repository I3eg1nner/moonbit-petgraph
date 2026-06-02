///|
/// Build a directed graph from a list of `(src_index, dst_index)` edges.
///
/// Nodes are auto-created so that every referenced index exists: if the largest
/// endpoint index is `m`, the graph has `m + 1` nodes (ids `0 .. m`). Each
/// node's weight is its own index (`N = Int`); edges carry `Unit` weight.
///
/// This is the MoonBit analogue of petgraph's
/// `Graph::<(), ()>::from_edges(&[(0,1), ...])`, specialized to integer
/// endpoints. Edges are added in the given order, so neighbor lists follow the
/// usual reverse-insertion ordering.
pub fn from_edges(edges : Array[(Int, Int)]) -> Graph[Int, Unit] {
  build_from_edges(edges, Directed)
}

///|
/// Like `from_edges`, but builds an undirected graph.
pub fn from_edges_undirected(edges : Array[(Int, Int)]) -> Graph[Int, Unit] {
  build_from_edges(edges, Undirected)
}

///|
/// Shared implementation for `from_edges` / `from_edges_undirected`.
fn build_from_edges(
  edges : Array[(Int, Int)],
  ty : Directedness,
) -> Graph[Int, Unit] {
  let g : Graph[Int, Unit] = match ty {
    Directed => Graph::new()
    Undirected => Graph::new_undirected()
  }
  for e in edges {
    let (src, dst) = e
    // Grow the node set until both endpoints exist (weights = own index).
    let nx = if src > dst { src } else { dst }
    while g.node_count() <= nx {
      let _ = g.add_node(g.node_count())
    }
    let _ = g.add_edge(NodeId::new(src), NodeId::new(dst), ())
  }
  g
}
