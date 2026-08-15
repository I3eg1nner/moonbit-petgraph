// Regression tests for degenerate max-flow inputs.
//
// Upstream petgraph's `dinics` does not terminate when `source == destination`:
// the level graph always places the destination at a positive level, so the
// outer loop never sees a level of zero, while each round finds only empty
// augmenting paths and adds nothing. This port guards the case explicitly and
// reports zero flow. `ford_fulkerson` already terminated on its own.

///|
/// A trivial two-node graph with a single capacity-5 arc.
fn degenerate_graph() -> @graph.Graph[Int, Int] {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  g.add_edge(a, b, 5) |> ignore
  g
}

///|
test "max flow from a node to itself is zero and terminates" {
  let g = degenerate_graph()
  let a = @graph.NodeId::new(0)
  let cost = e => g.edge_weight(e).unwrap()
  let (dinics_flow, dinics_edges) = @algo.dinics(
    g,
    source=a,
    destination=a,
    edge_cost=cost,
  )
  let (ff_flow, ff_edges) = @algo.ford_fulkerson(
    g,
    source=a,
    destination=a,
    edge_cost=cost,
  )
  assert_eq(dinics_flow, 0)
  assert_eq(ff_flow, 0)
  // No edge carries flow either.
  assert_eq(dinics_edges, [0])
  assert_eq(ff_edges, [0])
}

///|
test "max flow to an unreachable sink is zero" {
  let g = degenerate_graph()
  let isolated = g.add_node(2)
  let cost = e => g.edge_weight(e).unwrap()
  let (dinics_flow, _) = @algo.dinics(
    g,
    source=@graph.NodeId::new(0),
    destination=isolated,
    edge_cost=cost,
  )
  let (ff_flow, _) = @algo.ford_fulkerson(
    g,
    source=@graph.NodeId::new(0),
    destination=isolated,
    edge_cost=cost,
  )
  assert_eq(dinics_flow, 0)
  assert_eq(ff_flow, 0)
}
