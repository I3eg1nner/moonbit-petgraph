///|
/// Raised by `toposort` when the graph contains a cycle (including a self loop).
/// Carries a representative node that participates in the cycle, mirroring
/// petgraph's `Cycle<NodeId>`.
pub suberror Cycle {
  Cycle(@graph.NodeId)
} derive(Debug)

///|
/// Topological sort of a directed graph.
///
/// Returns an `order` where every node appears before all of its successors, if
/// the graph is acyclic. If the graph contains a cycle (including a self loop),
/// raises `Cycle(node)` for some node that participates in the cycle. Use `try?`
/// for a `Result[Array[NodeId], Cycle]` if you prefer to match on the outcome.
///
/// Implemented with the `@visit.Topo` (Kahn-style) walker, which yields nodes in
/// topological order while skipping any node that is still blocked by an
/// in-cycle predecessor. If the emitted order does not cover every node, the
/// graph has a cycle; we then locate and report a representative cycle node.
pub fn[G : @graph.NeighborSource] toposort(
  g : G,
) -> Array[@graph.NodeId] raise Cycle {
  let order = []
  let topo = @visit.Topo::new(g)
  while topo.next(g) is Some(nx) {
    order.push(nx)
  }
  if order.length() == g.node_count() {
    order
  } else {
    // Some nodes were never emitted -> they lie on (or behind) a cycle.
    // Report one such node, preferring one that is itself part of a cycle.
    raise Cycle(find_cycle_node(g, order))
  }
}

///|
/// Given the set of nodes that `Topo` *did* emit, find a node that was not
/// emitted and return a representative cycle node reachable from it.
fn[G : @graph.NeighborSource] find_cycle_node(
  g : G,
  emitted : Array[@graph.NodeId],
) -> @graph.NodeId {
  let n = g.node_count()
  let in_order = Array::make(n, false)
  for node in emitted {
    in_order[node.index()] = true
  }
  // The first non-emitted node is blocked by a cycle; walk forward following
  // not-yet-emitted successors until we revisit a node -> that node is on a
  // cycle.
  let start = (for i in 0..<n {
    if !in_order[i] {
      break Some(@graph.NodeId::new(i))
    }
  } nobreak {
    None
  }).unwrap()
  let seen = Array::make(n, false)
  for node = start {
    if seen[node.index()] {
      break node
    }
    seen[node.index()] = true
    let mut nxt = None
    for succ in g.neighbors_directed(node, Outgoing) {
      if !in_order[succ.index()] {
        nxt = Some(succ)
        break
      }
    }
    match nxt {
      Some(s) => continue s
      // No unemitted successor (e.g. self-loop already marked seen on next
      // iteration); node itself is the cycle witness.
      None => break node
    }
  }
}
