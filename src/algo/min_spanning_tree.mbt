///|
/// Compute a minimum spanning tree (forest) of a graph using Kruskal's
/// algorithm. The graph is treated as undirected.
///
/// Returns the set of edges (in increasing-weight order) that make up a minimum
/// spanning forest: for each edge, in nondecreasing `edge_cost` order, the edge
/// is kept iff its endpoints lie in different components (joined via union-find).
/// For a connected graph this yields `node_count - 1` edges; for a disconnected
/// graph it yields a spanning tree per component.
///
/// Port of petgraph's `algo::min_spanning_tree` (Kruskal). Edges are ordered with
/// the same `MinScored` max-heap used by Dijkstra, so the lightest edge is
/// processed first.
pub fn[N, E, K : Measure] min_spanning_tree(
  g : @graph.Graph[N, E],
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Array[@graph.EdgeId] {
  let subgraphs = @unionfind.UnionFind::new(g.node_count())
  let sort_edges : @priority_queue.PriorityQueue[MinScored[K, @graph.EdgeId]] = @priority_queue.PriorityQueue([],
  )
  for edge in g.edge_ids() {
    sort_edges.push(MinScored(edge_cost(edge), edge))
  }
  let mst : Array[@graph.EdgeId] = []
  while sort_edges.pop() is Some(MinScored(_, edge)) {
    guard g.edge_endpoints(edge) is Some((a, b)) else { continue }
    // Only keep the edge if its endpoints were in distinct components.
    if subgraphs.union(a.index(), b.index()) {
      mst.push(edge)
    }
  }
  mst
}
