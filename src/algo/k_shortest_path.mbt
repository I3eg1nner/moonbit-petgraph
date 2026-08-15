///|
/// k'th shortest path algorithm.
///
/// Computes the length of the `k`-th shortest path from `start` to every
/// reachable node. Edge costs must be non-negative. Paths are counted with
/// repetitions, so walks that revisit nodes count as separate paths — with
/// `k = 1` this degenerates into `dijkstra`.
///
/// If `goal` is `Some(t)`, the search stops as soon as `t` has been reached for
/// the `k`-th time.
///
/// Direct port of petgraph's `algo::k_shortest_path`. The same min-heap of
/// `MinScored` entries as `dijkstra` is used, but nothing is ever marked
/// visited: a node is instead popped up to `k` times, and the `k`-th pop is the
/// one recorded in the result. Nodes reached fewer than `k` times (including
/// unreachable ones) are absent from the returned map.
///
/// Time complexity **O(k|E| log(k|E|))**, auxiliary space **O(|V| + k|E|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // A 3-cycle with unit weights. The 1st walk from `a` to itself is the
///   // empty one, so the 2nd costs a full lap: 3.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   let a = g.add_node(0)
///   let b = g.add_node(1)
///   let c = g.add_node(2)
///   let _ = g.add_edge(a, b, 1)
///   let _ = g.add_edge(b, c, 1)
///   let _ = g.add_edge(c, a, 1)
///   let res = @algo.k_shortest_path(g, start=a, k=2, edge_cost=_ => 1)
///   inspect(res[a], content="3")
///   inspect(res[b], content="4")
/// }
/// ```
pub fn[N, E, K : Measure] k_shortest_path(
  g : @graph.Graph[N, E],
  start~ : @graph.NodeId,
  goal? : @graph.NodeId,
  k~ : Int,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Map[@graph.NodeId, K] {
  // How many times each node has been popped from the queue so far.
  let counter : Array[Int] = Array::make(g.node_count(), 0)
  let scores : Map[@graph.NodeId, K] = Map([])
  let visit_next : @priority_queue.PriorityQueue[MinScored[K, @graph.NodeId]] = PriorityQueue([],
  )
  visit_next.push(MinScored(K::zero(), start))
  while visit_next.pop() is Some(MinScored(node_score, node)) {
    let i = node.index()
    counter[i] = counter[i] + 1
    let current_counter = counter[i]
    if current_counter > k {
      continue
    }
    if current_counter == k {
      scores[node] = node_score
    }
    // Already reached the goal k times.
    if goal is Some(target) && node == target && current_counter == k {
      break
    }
    for edge in g.edges_directed(node, Outgoing) {
      guard edge_far_endpoint(g, edge, node) is Some(next) else { continue }
      visit_next.push(MinScored(node_score.add(edge_cost(edge)), next))
    }
  }
  scores
}
