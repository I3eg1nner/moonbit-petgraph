// Regression tests for undirected traversal in the weighted shortest-path
// algorithms.
//
// An undirected edge is stored once, with a fixed `(src, dst)` pair, and shows
// up in BOTH endpoints' incident-edge lists. An algorithm that walks a node's
// incident edges and then always reads the edge's stored `dst` as "the
// neighbour" therefore walks straight back into the node it started from
// whenever the edge happens to be stored as `(other, node)`.
//
// `dijkstra`, `astar` and `bellman_ford` all had exactly that defect: they
// paired `edges_directed(node, Outgoing)` with `edge_endpoints(e).1`. On an
// undirected graph they explored only the edges that happened to be stored in
// the convenient direction, silently reporting unreachable nodes. The fix is to
// walk `Graph::edges(node)`, which normalizes each incident edge so `target` is
// the endpoint away from `node` — petgraph's `Edges` / `EdgeRef::target`
// semantics.
//
// Every fixture below stores its edges "backwards" (higher index as source), so
// the buggy code path reports distances for the source node only.

///|
/// The undirected path `0 -- 1 -- 2 -- 3`, unit weights, with every edge stored
/// as `(higher, lower)` so that walking from node 0 requires reading the edge's
/// stored *source* rather than its stored target.
fn backwards_path() -> @graph.Graph[Int, Int] {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  for i in 0..<4 {
    g.add_node(i) |> ignore
  }
  g.add_edge(@graph.NodeId::new(1), @graph.NodeId::new(0), 1) |> ignore
  g.add_edge(@graph.NodeId::new(2), @graph.NodeId::new(1), 1) |> ignore
  g.add_edge(@graph.NodeId::new(3), @graph.NodeId::new(2), 1) |> ignore
  g
}

///|
/// Edge weight reader for the fixtures above.
fn backwards_cost(g : @graph.Graph[Int, Int]) -> (@graph.EdgeId) -> Int {
  e => g.edge_weight(e).unwrap()
}

///|
test "dijkstra traverses undirected edges stored backwards" {
  let g = backwards_path()
  let d = @algo.dijkstra(
    g,
    start=@graph.NodeId::new(0),
    edge_cost=backwards_cost(g),
  )
  // All four nodes reachable, at distances 0, 1, 2, 3.
  assert_eq(d.length(), 4)
  for i in 0..<4 {
    assert_eq(d.get(@graph.NodeId::new(i)), Some(i))
  }
}

///|
test "dijkstra is symmetric on an undirected graph" {
  let g = backwards_path()
  // Searching from the far end must give the mirrored distances.
  let d = @algo.dijkstra(
    g,
    start=@graph.NodeId::new(3),
    edge_cost=backwards_cost(g),
  )
  assert_eq(d.length(), 4)
  for i in 0..<4 {
    assert_eq(d.get(@graph.NodeId::new(i)), Some(3 - i))
  }
}

///|
test "astar traverses undirected edges stored backwards" {
  let g = backwards_path()
  let r = @algo.astar(
    g,
    start=@graph.NodeId::new(0),
    is_goal=n => n == @graph.NodeId::new(3),
    edge_cost=backwards_cost(g),
    estimate_cost=_ => 0,
  )
  guard r is Some((cost, path)) else { fail("astar found no path") }
  assert_eq(cost, 3)
  assert_eq(path.map(n => n.index()), [0, 1, 2, 3])
}

///|
test "bellman_ford traverses undirected edges stored backwards" {
  let g = backwards_path()
  let paths = @algo.bellman_ford(
    g,
    source=@graph.NodeId::new(0),
    edge_cost=backwards_cost(g),
  )
  for i in 0..<4 {
    assert_eq(paths.distances[i], Some(i))
  }
}

///|
test "undirected self-loops are not mistaken for progress" {
  // A self-loop's two endpoints are equal, so endpoint normalization must
  // report the node itself and must not be double-counted.
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let a = g.add_node(0)
  let b = g.add_node(1)
  g.add_edge(a, a, 5) |> ignore
  g.add_edge(b, a, 2) |> ignore
  let d = @algo.dijkstra(g, start=a, edge_cost=backwards_cost(g))
  assert_eq(d.get(a), Some(0))
  assert_eq(d.get(b), Some(2))
}
