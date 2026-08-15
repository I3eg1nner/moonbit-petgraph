///|
/// [DSatur algorithm](https://en.wikipedia.org/wiki/DSatur) to properly color a
/// non-weighted undirected graph.
///
/// This is a heuristic, so it does not necessarily return a minimum coloring.
/// The graph must be undirected and should not contain loops.
///
/// Returns a pair of:
/// * a `Map` that associates to each `NodeId` its color, and
/// * the number of used colors.
///
/// Port of petgraph's `algo::dsatur_coloring`. Nodes are processed out of a
/// max-heap keyed on `(saturation, degree)` — the number of distinct colors
/// already used by neighbors, then the node degree — exactly as petgraph's
/// `MaxScored((adj_color.len(), degree))`. petgraph leaves ties between equal
/// keys to `BinaryHeap`'s unspecified order; here the node index is appended as
/// a third key component so the result is deterministic.
///
/// As in petgraph, the reported color count is `max_color + 1`, so an empty
/// graph reports `1`.
///
/// Time complexity: **O((|V| + |E|)log|V|)**. Auxiliary space: **O(|V| + |E|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // A 6-cycle is bipartite, so two colors suffice.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges_undirected([
///     (0, 1),
///     (1, 2),
///     (2, 3),
///     (3, 4),
///     (4, 5),
///     (5, 0),
///   ])
///   let (coloring, nb_colors) = @algo.dsatur_coloring(g)
///   debug_inspect(nb_colors, content="2")
///   debug_inspect(coloring.length(), content="6")
/// }
/// ```
pub fn[N, E] dsatur_coloring(
  g : @graph.Graph[N, E],
) -> (Map[@graph.NodeId, Int], Int) {
  let n = g.node_count()
  let degree_map = Array::make(n, 0)
  // Max-heap keyed on (saturation, degree, node index); `pop` returns the
  // largest, i.e. the most saturated node, breaking ties on degree.
  let queue : @priority_queue.PriorityQueue[(Int, Int, Int)] = PriorityQueue([])
  let colored : Map[@graph.NodeId, Int] = Map([])
  let adj_color_map : Array[Map[Int, Unit]] = Array::makei(n, _ => Map([]))
  let seen = @visit.VisitMap::new(n)
  let mut max_color = 0
  for node in g.node_ids() {
    let degree = g.edges_directed(node, Outgoing).count()
    queue.push((0, degree, node.index()))
    degree_map[node.index()] = degree
  }
  while queue.pop() is Some((_, _, idx)) {
    let node = @graph.NodeId::new(idx)
    if seen.is_visited(node) {
      continue
    }
    seen.visit(node) |> ignore
    // The smallest color not already used by a neighbor.
    let adj_color = adj_color_map[idx]
    let mut color = 0
    while adj_color.contains(color) {
      color = color + 1
    }
    colored[node] = color
    if color > max_color {
      max_color = color
    }
    // Neighbors gain a saturation point and are re-pushed with their new key.
    for nbor in g.neighbors(node) {
      let ni = nbor.index()
      if ni < n {
        adj_color_map[ni][color] = ()
        queue.push((adj_color_map[ni].length(), degree_map[ni], ni))
      }
    }
  }
  (colored, max_color + 1)
}
