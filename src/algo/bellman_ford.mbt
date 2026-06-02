///|
/// Result of a successful `bellman_ford` run.
///
/// Both arrays are indexed by node index (`NodeId::index()`), which for a
/// `@graph.Graph` is a compact range `0 ..< node_count`.
///
/// * `distances[i]` is `Some(d)` if node `i` is reachable from the source with
///   shortest distance `d`, or `None` if `i` is unreachable (the "infinity"
///   case in petgraph's `FloatMeasure`-based implementation).
/// * `predecessors[i]` is `Some(p)` where `p` is the predecessor of node `i` on
///   a shortest path from the source, or `None` for the source itself and for
///   unreachable nodes.
pub struct BellmanFordPaths[K] {
  distances : Array[K?]
  predecessors : Array[@graph.NodeId?]
} derive(Debug)

///|
/// Raised by `bellman_ford` when the graph contains a negative-weight cycle
/// reachable from the source, in which case shortest distances are undefined.
pub suberror NegativeCycle derive(Debug)

///|
/// Bellman-Ford shortest-path algorithm.
///
/// Computes shortest paths from `source` to every node. Negative edge costs are
/// permitted; if a negative-weight cycle is reachable from `source`, raises
/// `NegativeCycle`.
///
/// Direct port of petgraph's `algo::bellman_ford`. "Infinity" distances are
/// modeled as `None` (so `bellman_ford` works for any `Measure`, not only float
/// weights): relaxation only ever compares/updates *finite* tentative
/// distances, so an unreachable node stays `None`.
///
/// On success returns `BellmanFordPaths { distances, predecessors }` indexed by
/// node index.
///
/// # Example
/// ```mbt check
/// test {
///   // Direct edge 0 ->10-> 2 is dearer than the detour 0 ->2-> 1 ->3-> 2.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   let n0 = g.add_node(0)
///   let n1 = g.add_node(1)
///   let n2 = g.add_node(2)
///   let _ = g.add_edge(n0, n1, 2)
///   let _ = g.add_edge(n1, n2, 3)
///   let _ = g.add_edge(n0, n2, 10)
///   // `bellman_ford` raises `NegativeCycle` if a reachable negative cycle
///   // exists; this graph has none, so the call returns normally.
///   let paths = @algo.bellman_ford(g, source=n0, edge_cost=fn(e) {
///     g.edge_weight(e).unwrap()
///   })
///   // Cheapest 0 ~> 2 is 0->1->2 = 5.
///   debug_inspect(paths.distances[n2.index()], content="Some(5)")
/// }
/// ```
pub fn[N, E, K : Measure] bellman_ford(
  g : @graph.Graph[N, E],
  source~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> BellmanFordPaths[K] raise NegativeCycle {
  let n = g.node_count()
  let (distances, predecessors) = bellman_ford_initialize_relax(
    g,
    source~,
    edge_cost~,
  )

  // Step 3: check for a negative-weight cycle.
  for i in 0..<n {
    let u = @graph.NodeId::new(i)
    match distances[i] {
      None => continue // unreachable: cannot relax further
      Some(du) =>
        for edge in g.edges_directed(u, Outgoing) {
          guard g.edge_endpoints(edge) is Some((_, v)) else { continue }
          let candidate = du.add(edge_cost(edge))
          let j = v.index()
          let improves = match distances[j] {
            None => true
            Some(dv) => candidate.compare(dv) < 0
          }
          if improves {
            raise NegativeCycle
          }
        }
    }
  }
  { distances, predecessors }
}

///|
/// Steps 1 and 2 of Bellman-Ford: initialize distances/predecessors and relax
/// all edges up to `node_count - 1` times (stopping early once a full pass makes
/// no update).
fn[N, E, K : Measure] bellman_ford_initialize_relax(
  g : @graph.Graph[N, E],
  source~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> (Array[K?], Array[@graph.NodeId?]) {
  let n = g.node_count()
  let distances : Array[K?] = Array::make(n, None)
  let predecessors : Array[@graph.NodeId?] = Array::make(n, None)
  distances[source.index()] = Some(K::zero())
  for _iter in 1..<n {
    let mut did_update = false
    for i in 0..<n {
      let u = @graph.NodeId::new(i)
      guard distances[i] is Some(du) else { continue }
      for edge in g.edges_directed(u, Outgoing) {
        guard g.edge_endpoints(edge) is Some((_, v)) else { continue }
        let candidate = du.add(edge_cost(edge))
        let j = v.index()
        let improves = match distances[j] {
          None => true
          Some(dv) => candidate.compare(dv) < 0
        }
        if improves {
          distances[j] = Some(candidate)
          predecessors[j] = Some(u)
          did_update = true
        }
      }
    }
    if !did_update {
      break
    }
  }
  (distances, predecessors)
}
