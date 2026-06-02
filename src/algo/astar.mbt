///|
/// A* shortest-path algorithm.
///
/// Computes the shortest path from `start` to the first node for which
/// `is_goal` returns `true`, together with the total path cost.
///
/// * `edge_cost` returns the (non-negative) cost of an edge.
/// * `estimate_cost` returns an *admissible* heuristic estimate of the remaining
///   cost from a node to the nearest goal (it must never overestimate, and must
///   be non-negative). With `estimate_cost = (_) => K::zero()`, A* degenerates to
///   Dijkstra.
///
/// Returns `Some((total_cost, path))` where `path` runs from `start` to the goal
/// inclusive, or `None` if no goal is reachable.
///
/// Direct port of petgraph's `algo::astar`. The open set is a max-heap of
/// `MinScored(f, node)` entries (reversed ordering ⇒ smallest `f` first), and the
/// per-node score tracks `(f, h, g)` exactly as petgraph does.
pub fn[N, E, K : Measure] astar(
  g : @graph.Graph[N, E],
  start~ : @graph.NodeId,
  is_goal~ : (@graph.NodeId) -> Bool,
  edge_cost~ : (@graph.EdgeId) -> K,
  estimate_cost~ : (@graph.NodeId) -> K,
) -> (K, Array[@graph.NodeId])? {
  let visit_next : @priority_queue.PriorityQueue[MinScored[K, @graph.NodeId]] = @priority_queue.PriorityQueue([],
  )
  // node -> (f, h, g)
  let scores : Map[@graph.NodeId, (K, K, K)] = {}
  // search tree: node -> predecessor
  let came_from : Map[@graph.NodeId, @graph.NodeId] = {}
  let zero = K::zero()
  let h0 = estimate_cost(start)
  scores[start] = (zero.add(h0), h0, zero)
  visit_next.push(MinScored(zero.add(h0), start))
  while visit_next.pop() is Some(MinScored(_, node)) {
    if is_goal(node) {
      let path = reconstruct_path(came_from, node)
      let (goal_f, _, _) = scores.get(node).unwrap()
      return Some((goal_f, path))
    }
    // Skip if this node has already been expanded with a strictly better g.
    let (_, _, g_node) = scores.get(node).unwrap()
    for edge in g.edges_directed(node, Outgoing) {
      guard g.edge_endpoints(edge) is Some((_, neigh)) else { continue }
      let neigh_g = g_node.add(edge_cost(edge))
      let neigh_h = estimate_cost(neigh)
      let neigh_f = neigh_g.add(neigh_h)
      let better = match scores.get(neigh) {
        Some((_, _, old_g)) => neigh_g.compare(old_g) < 0
        None => true
      }
      if better {
        scores[neigh] = (neigh_f, neigh_h, neigh_g)
        came_from[neigh] = node
        visit_next.push(MinScored(neigh_f, neigh))
      }
    }
  }
  None
}

///|
/// Reconstruct the path from `start` to `last` by following predecessor links.
fn reconstruct_path(
  came_from : Map[@graph.NodeId, @graph.NodeId],
  last : @graph.NodeId,
) -> Array[@graph.NodeId] {
  let path = [last]
  let mut current = last
  while came_from.get(current) is Some(prev) {
    path.push(prev)
    current = prev
  }
  path.rev()
}
