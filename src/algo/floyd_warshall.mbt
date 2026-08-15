///|
/// Floyd–Warshall all-pairs shortest paths.
///
/// Computes the length of every shortest path in a weighted graph whose edge
/// costs may be positive *or* negative, provided there is no negative cycle.
/// Raises `NegativeCycle` if one exists.
///
/// Direct port of petgraph's `algo::floyd_warshall`:
///
/// * The distance matrix starts filled with `BoundedMeasure::max_value()`, the
///   saturating "infinity" sentinel for unreachable pairs.
/// * Each edge lowers `dist[source][target]` only if it is cheaper than what is
///   already there, so parallel edges keep the minimum. For an undirected graph
///   the symmetric entry is filled in as well.
/// * The diagonal is then forced to `zero()`, which also cancels any self-loop.
/// * Relaxation uses `checked_add`, so a path through the "infinity" sentinel
///   overflows and is discarded instead of wrapping around into a bogus short
///   path.
/// * Finally a negative entry on the diagonal signals a negative cycle.
///
/// The result maps every ordered pair `(i, j)` of node ids — including
/// unreachable ones, which map to `max_value()` — to its shortest distance.
///
/// Time complexity **O(|V|³)**, auxiliary space **O(|V|²)**.
///
/// # Example
/// ```mbt check
/// test {
///   // a ->1-> b ->2-> c, plus the dearer direct edge a ->4-> c.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   let a = g.add_node(0)
///   let b = g.add_node(1)
///   let c = g.add_node(2)
///   let _ = g.add_edge(a, b, 1)
///   let _ = g.add_edge(b, c, 2)
///   let _ = g.add_edge(a, c, 4)
///   let res = @algo.floyd_warshall(g, edge_cost=e => g.edge_weight(e).unwrap())
///   inspect(res[(a, c)], content="3")
///   // c cannot reach a, so the pair saturates at `max_value()`.
///   inspect(res[(c, a)], content="2147483647")
/// }
/// ```
pub fn[N, E, K : BoundedMeasure] floyd_warshall(
  g : @graph.Graph[N, E],
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Map[(@graph.NodeId, @graph.NodeId), K] raise NegativeCycle {
  let n = g.node_count()
  let inf = K::max_value()
  let zero : K = Measure::zero()
  // |V| x |V| matrix; `Array::makei` so every row is a distinct array.
  let dist : Array[Array[K]] = Array::makei(n, _ => Array::make(n, inf))

  // Initialize the distances of the direct edges, keeping the cheapest of any
  // parallel edges.
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((src, dst)) else { continue }
    let (i, j) = (src.index(), dst.index())
    let cost = edge_cost(edge)
    if Measure::compare(dist[i][j], cost) > 0 {
      dist[i][j] = cost
      if !g.is_directed() {
        dist[j][i] = cost
      }
    }
  }

  // The distance of each node to itself is the additive identity.
  for i in 0..<n {
    dist[i][i] = zero
  }

  // The Floyd-Warshall triple loop.
  for k in 0..<n {
    for i in 0..<n {
      for j in 0..<n {
        // `checked_add` plays the role of petgraph's `overflowing_add`: a sum
        // that overflows (typically because it runs through the `max_value()`
        // sentinel) is never a shortest path.
        if dist[i][k].checked_add(dist[k][j]) is Some(result) &&
          Measure::compare(dist[i][j], result) > 0 {
          dist[i][j] = result
        }
      }
    }
  }

  // A diagonal entry below zero means the node lies on a negative cycle.
  for i in 0..<n {
    if Measure::compare(dist[i][i], zero) < 0 {
      raise NegativeCycle
    }
  }
  let out : Map[(@graph.NodeId, @graph.NodeId), K] = Map([])
  for i in 0..<n {
    for j in 0..<n {
      out[(@graph.NodeId::new(i), @graph.NodeId::new(j))] = dist[i][j]
    }
  }
  out
}
