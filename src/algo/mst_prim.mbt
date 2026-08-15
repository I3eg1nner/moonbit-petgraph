///|
/// Compute a minimum spanning tree of a graph using Prim's algorithm. The graph
/// is treated as undirected.
///
/// Returns the set of edges that make up the minimum spanning tree, in the order
/// Prim's algorithm adds them (the tree grows out of the first node of the
/// graph). This is the same return shape as the Kruskal-based
/// `min_spanning_tree`, so the two are interchangeable; for a connected graph
/// both return `node_count - 1` edges of the same total weight.
///
/// The graph is treated as if it were connected: only the component containing
/// node `0` is spanned. Use `min_spanning_tree` (Kruskal) when a minimum
/// spanning *forest* of a disconnected graph is wanted.
///
/// # Complexity
/// * Time: **O(|E| log |V|)**, auxiliary space **O(|V| + |E|)**.
///
/// Port of petgraph's `algo::min_spanning_tree_prim`. As upstream, edges are
/// ordered with the `MinScored` max-heap (reversed on the score) that Dijkstra
/// uses, so the lightest edge leaving the tree is processed first, and an edge
/// is kept iff its far endpoint is not yet part of the tree.
pub fn[N, E, K : Measure] min_spanning_tree_prim(
  g : @graph.Graph[N, E],
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Array[@graph.EdgeId] {
  let mst : Array[@graph.EdgeId] = []
  // An empty graph has no initial node to bootstrap Prim's algorithm with.
  guard g.node_count() > 0 else { return mst }
  let nodes_taken = Array::make(g.node_count(), false)
  let sort_edges : @priority_queue.PriorityQueue[
    MinScored[K, (@graph.EdgeId, @graph.NodeId)],
  ] = PriorityQueue([])

  // Bootstrap: mark the initial node as taken and queue its incident edges,
  // each paired with the endpoint that would join the tree.
  let initial_node = @graph.NodeId::new(0)
  nodes_taken[initial_node.index()] = true
  for edge in g.edges_directed(initial_node, Outgoing) {
    let target = edge_other_endpoint(g, edge, initial_node)
    sort_edges.push(MinScored(edge_cost(edge), (edge, target)))
  }

  // Prim's algorithm: pop the lightest edge leaving the tree; keep it iff its
  // far endpoint is not in the tree yet, then queue that endpoint's edges.
  while sort_edges.pop() is Some(MinScored(_, (edge, target))) {
    if nodes_taken[target.index()] {
      continue
    }
    nodes_taken[target.index()] = true
    mst.push(edge)
    for next_edge in g.edges_directed(target, Outgoing) {
      let next_target = edge_other_endpoint(g, next_edge, target)
      sort_edges.push(MinScored(edge_cost(next_edge), (next_edge, next_target)))
    }
  }
  mst
}
