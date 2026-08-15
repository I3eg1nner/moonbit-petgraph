///|
/// Johnson's algorithm for all-pairs shortest paths.
///
/// Computes the lengths of the shortest paths in a weighted graph whose edge
/// costs may be positive *or* negative, provided there is no negative cycle.
/// Raises `NegativeCycle` if one exists.
///
/// Direct port of petgraph's `algo::johnson`. A virtual node with a zero-weight
/// edge to every vertex is simulated by seeding SPFA with *all* vertices at
/// distance `zero()`; the resulting potentials `h` are then used to reweight
/// each edge `(u, v)` to `w(u, v) + h(u) - h(v)`, which is provably
/// non-negative, so Dijkstra can be run once per source. Each distance is
/// finally un-shifted with `dist + h(target) - h(source)`.
///
/// The result maps `(source, target)` to the shortest distance; pairs with no
/// path between them are simply absent, exactly as upstream (which collects
/// Dijkstra's per-source map).
///
/// Time complexity **O(|V||E|log(|V|) + |V|²log(|V|))**, which beats
/// `floyd_warshall` on sparse graphs and loses on dense ones. Auxiliary space
/// **O(|V|² + |V||E|)**.
///
/// petgraph's `parallel_johnson` (the `rayon`-based variant) is deliberately not
/// ported: MoonBit has no thread-based data parallelism here, and it computes
/// the same result.
///
/// # Example
/// ```mbt check
/// test {
///   // A negative edge that no negative cycle can exploit.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   let a = g.add_node(0)
///   let b = g.add_node(1)
///   let c = g.add_node(2)
///   let _ = g.add_edge(a, b, 3)
///   let _ = g.add_edge(b, c, -2)
///   let _ = g.add_edge(a, c, 4)
///   let res = @algo.johnson(g, edge_cost=e => g.edge_weight(e).unwrap())
///   debug_inspect(res.get((a, c)), content="Some(1)")
///   // No path from c back to a.
///   debug_inspect(res.get((c, a)), content="None")
/// }
/// ```
pub fn[N, E, K : BoundedMeasure] johnson(
  g : @graph.Graph[N, E],
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Map[(@graph.NodeId, @graph.NodeId), K] raise NegativeCycle {
  let reweight = johnson_reweight(g, edge_cost~)
  let out : Map[(@graph.NodeId, @graph.NodeId), K] = Map([])
  // Run Dijkstra's algorithm from each node over the reweighted edges.
  for source in g.node_ids() {
    let s = source.index()
    for pair in johnson_dijkstra(g, source, reweight, edge_cost).to_array() {
      let (target, dist) = pair
      out[(source, target)] = Measure::add(dist, reweight[target.index()]).sub(
        reweight[s],
      )
    }
  }
  out
}

///|
/// Compute Johnson's potentials: add a virtual node joined to every vertex by a
/// zero-weight edge and run SPFA from it.
///
/// Seeding the SPFA queue with every vertex at distance `zero()` is exactly
/// equivalent, and is what petgraph's `johnson_reweight` does. Raises
/// `NegativeCycle` if the graph has one, since then no valid potential exists.
fn[N, E, K : BoundedMeasure] johnson_reweight(
  g : @graph.Graph[N, E],
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Array[K] raise NegativeCycle {
  let n = g.node_count()
  let reweight : Array[K] = Array::make(n, Measure::zero())
  let queue : @deque.Deque[@graph.NodeId] = Deque([])
  for node in g.node_ids() {
    queue.push_back(node)
  }
  let in_queue : Array[Bool] = Array::make(n, true)
  let no_predecessors : Array[@graph.NodeId?]? = None
  spfa_loop(g, reweight, no_predecessors, queue, in_queue, edge_cost)
  reweight
}

///|
/// Dijkstra from `source` over Johnson's reweighted costs
/// `w(u, v) + h(u) - h(v)`.
///
/// This mirrors this package's `dijkstra`, but the reweighting needs to know
/// which way round each edge is being traversed, which an
/// `(EdgeId) -> K` cost closure cannot express. Walking the edge list here lets
/// us use `edge_far_endpoint`, so the reweighting stays correct for undirected
/// graphs too.
fn[N, E, K : BoundedMeasure] johnson_dijkstra(
  g : @graph.Graph[N, E],
  source : @graph.NodeId,
  reweight : Array[K],
  edge_cost : (@graph.EdgeId) -> K,
) -> Map[@graph.NodeId, K] {
  let visited = @visit.VisitMap::new(g.node_count())
  let scores : Map[@graph.NodeId, K] = Map([])
  let visit_next : @priority_queue.PriorityQueue[MinScored[K, @graph.NodeId]] = PriorityQueue([],
  )
  let zero : K = Measure::zero()
  scores[source] = zero
  visit_next.push(MinScored(zero, source))
  while visit_next.pop() is Some(MinScored(node_score, node)) {
    if visited.is_visited(node) {
      continue
    }
    for edge in g.edges_directed(node, Outgoing) {
      guard edge_far_endpoint(g, edge, node) is Some(next) else { continue }
      if visited.is_visited(next) {
        continue
      }
      let cost = Measure::add(edge_cost(edge), reweight[node.index()]).sub(
        reweight[next.index()],
      )
      let next_score = Measure::add(node_score, cost)
      match scores.get(next) {
        Some(cur) =>
          if Measure::compare(next_score, cur) < 0 {
            scores[next] = next_score
            visit_next.push(MinScored(next_score, next))
          }
        None => {
          scores[next] = next_score
          visit_next.push(MinScored(next_score, next))
        }
      }
    }
    visited.visit(node) |> ignore
  }
  scores
}
