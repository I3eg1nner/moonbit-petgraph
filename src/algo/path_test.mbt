// Tests for the weighted shortest-path algorithms: dijkstra, astar,
// bellman_ford, and the dijkstra<->bellman_ford cross-check.

///|
/// Build a directed graph whose nodes carry their own index (`N = Int`) and
/// whose edges carry an `Int` weight (`E = Int`), from `(src, dst, weight)`
/// triples. Node ids `0 .. max_endpoint` are auto-created.
fn build_weighted(edges : Array[(Int, Int, Int)]) -> @graph.Graph[Int, Int] {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  for e in edges {
    let (src, dst, _) = e
    let nx = if src > dst { src } else { dst }
    while g.node_count() <= nx {
      g.add_node(g.node_count()) |> ignore
    }
  }
  for e in edges {
    let (src, dst, w) = e
    g.add_edge(@graph.NodeId::new(src), @graph.NodeId::new(dst), w) |> ignore
  }
  g
}

///|
/// `edge_cost` closure reading the edge's stored `Int` weight.
fn weight_of(g : @graph.Graph[Int, Int]) -> (@graph.EdgeId) -> Int {
  e => g.edge_weight(e).unwrap()
}

///|
/// Sort dijkstra's result map into `(node_index, distance)` pairs for stable
/// snapshotting.
fn sorted_dist(m : Map[@graph.NodeId, Int]) -> Array[(Int, Int)] {
  let out = [ for kv in m.to_array() => (kv.0.index(), kv.1) ]
  out.sort_by((a, b) => a.0.compare(b.0))
  out
}

///|
test "dijkstra unit weights (petgraph doc example)" {
  // Edges from petgraph's dijkstra doctest, run from b (index 1), unit weights.
  // a=0 b=1 c=2 d=3 e=4 f=5 g=6 h=7
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 0),
    (4, 5),
    (1, 4),
    (5, 6),
    (6, 7),
    (7, 4),
  ])
  let res = @algo.dijkstra(g, start=@graph.NodeId::new(1), edge_cost=_ => 1)
  // Expected (from petgraph doc): b0 c1 d2 a3 e1 f2 g3 h4
  json_inspect(sorted_dist(res), content=[
    [0, 3],
    [1, 0],
    [2, 1],
    [3, 2],
    [4, 1],
    [5, 2],
    [6, 3],
    [7, 4],
  ])
}

///|
test "dijkstra weighted with goal early stop" {
  // 0 ->(1) 1 ->(2) 2 ; 0 ->(4) 2 directly. Shortest 0->2 is 3 via 1.
  let g = build_weighted([(0, 1, 1), (1, 2, 2), (0, 2, 4), (2, 3, 5)])
  let res = @algo.dijkstra(
    g,
    start=@graph.NodeId::new(0),
    goal=@graph.NodeId::new(2),
    edge_cost=weight_of(g),
  )
  // Goal is node 2: search stops once 2 is settled, so 3 is NOT reached.
  json_inspect(sorted_dist(res), content=[[0, 0], [1, 1], [2, 3]])
}

///|
test "astar finds optimal path (petgraph doc example)" {
  // petgraph astar doctest graph; weights as given. Optimal a->d->e->f cost 6.
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g = build_weighted([
    (0, 1, 2),
    (0, 3, 4),
    (1, 2, 1),
    (1, 5, 7),
    (2, 4, 5),
    (4, 5, 1),
    (3, 4, 1),
  ])
  let f = @graph.NodeId::new(5)
  let result = @algo.astar(
    g,
    start=@graph.NodeId::new(0),
    is_goal=n => n == f,
    edge_cost=weight_of(g),
    estimate_cost=_ => 0,
  )
  guard result is Some((cost, path)) else { fail("astar found no path") }
  let path_idx = [ for n in path => n.index() ]
  inspect(cost, content="6")
  json_inspect(path_idx, content=[0, 3, 4, 5])
}

///|
test "astar no path returns None" {
  // node 2 is isolated (only an incoming-less target with no path from 0).
  let g = build_weighted([(0, 1, 1)])
  g.add_node(2) |> ignore
  let target = @graph.NodeId::new(2)
  let result = @algo.astar(
    g,
    start=@graph.NodeId::new(0),
    is_goal=n => n == target,
    edge_cost=weight_of(g),
    estimate_cost=_ => 0,
  )
  inspect(result is None, content="true")
}

///|
test "bellman_ford distances and predecessors (petgraph doc example)" {
  // Same shape as petgraph bellman_ford doctest but with Int weights.
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g = build_weighted([
    (0, 1, 2),
    (0, 3, 4),
    (1, 2, 1),
    (1, 5, 7),
    (2, 4, 5),
    (4, 5, 1),
    (3, 4, 1),
  ])
  let paths = @algo.bellman_ford(
    g,
    source=@graph.NodeId::new(0),
    edge_cost=weight_of(g),
  )
  let dist = [ for d in paths.distances => d.unwrap() ]
  json_inspect(dist, content=[0, 2, 3, 4, 5, 6])
  let preds : Array[Int] = []
  for p in paths.predecessors {
    let idx = match p {
      Some(n) => n.index()
      None => -1
    }
    preds.push(idx)
  }
  // None for source(0); pred of f(5) is e(4), of e is d(3), of d is a(0), etc.
  json_inspect(preds, content=[-1, 0, 1, 0, 3, 4])
}

///|
test "bellman_ford detects negative cycle" {
  // 0 -> 1 -> 2 -> 0 with total weight -1 forms a reachable negative cycle.
  let g = build_weighted([(0, 1, 1), (1, 2, -3), (2, 0, 1)])
  let result : Result[@algo.BellmanFordPaths[Int], Error] = try? @algo.bellman_ford(
    g,
    source=@graph.NodeId::new(0),
    edge_cost=weight_of(g),
  )
  inspect(result is Err(_), content="true")
}

///|
test "cross-check: dijkstra == bellman_ford on non-negative graph" {
  // A non-negative weighted DAG-ish graph; both algorithms must agree on
  // distances to every reachable node.
  let g = build_weighted([
    (0, 1, 3),
    (0, 2, 1),
    (2, 1, 1),
    (1, 3, 2),
    (2, 3, 6),
    (3, 4, 4),
    (0, 4, 20),
  ])
  let src = @graph.NodeId::new(0)
  let dij = @algo.dijkstra(g, start=src, edge_cost=weight_of(g))
  let bf = @algo.bellman_ford(g, source=src, edge_cost=weight_of(g))
  for i in 0..<g.node_count() {
    let node = @graph.NodeId::new(i)
    // Map "unreachable" to a sentinel so we compare plain Ints (avoids the
    // deprecated Show-on-Option path) while still checking reachability agrees.
    let d_dij = match dij.get(node) {
      Some(d) => d
      None => -1
    }
    let d_bf = match bf.distances[i] {
      Some(d) => d
      None => -1
    }
    assert_eq(d_dij, d_bf)
  }
}
