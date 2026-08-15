///|
/// Find a negative-weight cycle reachable from `source`.
///
/// Returns `Some(path)` with the nodes of one negative cycle, in the order they
/// are traversed, or `None` if no negative cycle is reachable from `source`.
///
/// Direct port of petgraph's `algo::find_negative_cycle`. Bellman-Ford's
/// initialize-and-relax phase is run first (shared with `bellman_ford`); if any
/// edge can still be relaxed afterwards, its target lies on — or downstream of —
/// a negative cycle, and the cycle is recovered by walking the predecessor
/// chain backwards until either the starting node is reached again or some node
/// is seen twice (in which case the prefix before that node is dropped). The
/// collected chain is finally reversed so that it reads forwards.
///
/// Time complexity **O(|V||E|)**, auxiliary space **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // 3 ->-3-> 2 makes the cycle 1 -> 3 -> 2 -> 1 negative.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   for i in 0..<4 {
///     let _ = g.add_node(i)
///   }
///   let n = i => @graph.NodeId::new(i)
///   for e in [(0, 1, 1), (0, 2, 1), (0, 3, 1), (1, 3, 1), (2, 1, 1), (3, 2, -3)] {
///     let _ = g.add_edge(n(e.0), n(e.1), e.2)
///   }
///   let cycle = @algo.find_negative_cycle(g, source=n(0), edge_cost=e => {
///     g.edge_weight(e).unwrap()
///   })
///   guard cycle is Some(path) else { fail("expected a negative cycle") }
///   json_inspect([ for n in path => n.index() ], content=[1, 3, 2])
/// }
/// ```
pub fn[N, E, K : Measure] find_negative_cycle(
  g : @graph.Graph[N, E],
  source~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Array[@graph.NodeId]? {
  let n = g.node_count()

  // Step 1: initialize and relax.
  let (distance, predecessor) = bellman_ford_initialize_relax(
    g,
    source~,
    edge_cost~,
  )

  // Step 2: look for an edge that can still be relaxed; its target starts the
  // walk back through the cycle.
  let mut start : @graph.NodeId? = None
  for i in 0..<n {
    let u = @graph.NodeId::new(i)
    guard distance[i] is Some(du) else { continue }
    for edge in g.edges_directed(u, Outgoing) {
      guard edge_far_endpoint(g, edge, u) is Some(v) else { continue }
      let candidate = du.add(edge_cost(edge))
      let improves = match distance[v.index()] {
        None => true
        Some(dv) => candidate.compare(dv) < 0
      }
      if improves {
        start = Some(v)
        break
      }
    }
    if start is Some(_) {
      break
    }
  }
  guard start is Some(cycle_start) else { return None }

  // Step 3: negative cycle found; walk backwards along the predecessors.
  let mut path : Array[@graph.NodeId] = []
  let visited = @visit.VisitMap::new(n)
  let mut node = cycle_start
  for ;; {
    let ancestor = match predecessor[node.index()] {
      Some(predecessor_node) => predecessor_node
      // No predecessor, self cycle.
      None => node
    }
    // We have only 2 ways to find the cycle and break the loop:
    // 1. the starting node is reached again
    if ancestor == cycle_start {
      path.push(ancestor)
      break
    } else if visited.is_visited(ancestor) {
      // 2. some node was reached twice: drop any node in the path that comes
      //    before the first occurrence of that ancestor.
      guard path.search(ancestor) is Some(pos) else { break }
      path = path[pos:].to_owned()
      break
    }
    // None of the above, some middle path node.
    path.push(ancestor)
    visited.visit(ancestor) |> ignore
    node = ancestor
  }
  if path.length() > 0 {
    // Users will probably want to follow the cycle, so hand it back in the
    // order it is traversed rather than the order it was discovered in.
    Some(path.rev())
  } else {
    None
  }
}
