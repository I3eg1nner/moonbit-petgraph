// Ported from petgraph's REAL tests/doctests for the weighted shortest-path
// algorithms: dijkstra (doctest in src/algo/dijkstra.rs), astar (doctest in
// src/algo/astar.rs and tests/graph.rs), and bellman_ford (doctest in
// src/algo/bellman_ford.rs). Original Rust test/doctest names are preserved as
// annotations on each block.

///|
/// Build a directed `Graph[Int,Int]` (node weight = its own index) from
/// `(src, dst, weight)` triples, auto-creating nodes `0 ..= max_endpoint`.
fn build_wg(edges : Array[(Int, Int, Int)]) -> @graph.Graph[Int, Int] {
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
/// Same as `build_wg` but with `Double` edge weights.
fn build_wgf(edges : Array[(Int, Int, Double)]) -> @graph.Graph[Int, Double] {
  let g : @graph.Graph[Int, Double] = @graph.Graph::new()
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
fn wt(g : @graph.Graph[Int, Int]) -> (@graph.EdgeId) -> Int {
  e => g.edge_weight(e).unwrap()
}

///|
/// petgraph doctest: src/algo/dijkstra.rs `dijkstra`
test "dijkstra doctest (unit weights from b)" {
  // a=0 b=1 c=2 d=3 e=4 f=5 g=6 h=7, z=8 in another component.
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
  g.add_node(8) |> ignore // z, unreachable from b
  let res = @algo.dijkstra(g, start=@graph.NodeId::new(1), edge_cost=_ => 1)
  // Expected map: a3 b0 c1 d2 e1 f2 g3 h4; z absent (no path from b).
  let pairs = [ for kv in res.to_array() => (kv.0.index(), kv.1) ]
  pairs.sort_by((a, b) => a.0.compare(b.0))
  json_inspect(pairs, content=[
    [0, 3],
    [1, 0],
    [2, 1],
    [3, 2],
    [4, 1],
    [5, 2],
    [6, 3],
    [7, 4],
  ])
  // z (index 8) is not reachable from b.
  inspect(res.get(@graph.NodeId::new(8)) is None, content="true")
}

///|
/// petgraph doctest: src/algo/astar.rs `astar`
test "astar doctest (optimal a->d->e->f cost 6)" {
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g = build_wg([
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
    edge_cost=wt(g),
    estimate_cost=_ => 0,
  )
  guard result is Some((cost, path)) else { fail("astar found no path") }
  inspect(cost, content="6")
  json_inspect([ for n in path => n.index() ], content=[0, 3, 4, 5])
}

///|
/// petgraph test: tests/graph.rs `test_astar_null_heuristic`
test "test_astar_null_heuristic" {
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g = build_wg([
    (0, 1, 7),
    (2, 0, 9),
    (0, 3, 14),
    (1, 2, 10),
    (3, 2, 2),
    (3, 4, 9),
    (1, 5, 15),
    (2, 5, 11),
    (4, 5, 6),
  ])
  let a = @graph.NodeId::new(0)
  let e = @graph.NodeId::new(4)
  let b = @graph.NodeId::new(1)
  let path = @algo.astar(g, start=a, is_goal=n => n == e, edge_cost=wt(g), estimate_cost=_ => {
    0
  })
  guard path is Some((cost, p)) else { fail("expected a path a->e") }
  inspect(cost, content="23")
  json_inspect([ for n in p => n.index() ], content=[0, 3, 4])
  // check against dijkstra
  let dij = @algo.dijkstra(g, start=a, goal=e, edge_cost=wt(g))
  inspect(dij.get(e) is Some(23), content="true")
  // No path from e back to b.
  let none_path = @algo.astar(
    g,
    start=e,
    is_goal=n => n == b,
    edge_cost=wt(g),
    estimate_cost=_ => 0,
  )
  inspect(none_path is None, content="true")
}

///|
/// petgraph test: tests/graph.rs `test_astar_manhattan_heuristic`
/// Uses Manhattan-distance coordinates as an admissible heuristic and
/// cross-checks every astar goal cost against dijkstra.
test "test_astar_manhattan_heuristic" {
  // a=0 b=1 c=2 d=3 e=4 f=5 ; node 6 (5.,5.) has no path.
  let coords : Array[(Double, Double)] = [
    (0.0, 0.0),
    (2.0, 0.0),
    (1.0, 1.0),
    (0.0, 2.0),
    (3.0, 2.0),
    (4.0, 2.0),
    (5.0, 5.0),
  ]
  let g = build_wgf([
    (0, 1, 2.0),
    (0, 3, 4.0),
    (1, 2, 1.0),
    (1, 5, 7.0),
    (2, 4, 5.0),
    (4, 5, 1.0),
    (3, 4, 1.0),
  ])
  g.add_node(6) |> ignore // (5.,5.), unreachable
  let ew = fn(e : @graph.EdgeId) -> Double { g.edge_weight(e).unwrap() }
  fn abs_d(x : Double) -> Double {
    if x < 0.0 {
      -x
    } else {
      x
    }
  }

  fn heuristic_for(goal : @graph.NodeId) -> (@graph.NodeId) -> Double {
    n => {
      let (x1, y1) = coords[n.index()]
      let (x2, y2) = coords[goal.index()]
      abs_d(x2 - x1) + abs_d(y2 - y1)
    }
  }

  let a = @graph.NodeId::new(0)
  let f = @graph.NodeId::new(5)
  let path = @algo.astar(
    g,
    start=a,
    is_goal=n => n == f,
    edge_cost=ew,
    estimate_cost=heuristic_for(f),
  )
  guard path is Some((cost, p)) else { fail("expected path a->f") }
  inspect(cost, content="6")
  json_inspect([ for n in p => n.index() ], content=[0, 3, 4, 5])

  // Dijkstra costs to all nodes; astar (with admissible heuristic) must agree.
  let dij = @algo.dijkstra(g, start=a, edge_cost=ew)
  for i in 0..<g.node_count() {
    let goal = @graph.NodeId::new(i)
    let h = heuristic_for(goal)(goal)
    // Heuristic at the goal is 0 (distance to self), trivially admissible.
    assert_eq(h, 0.0)
    let ap = @algo.astar(
      g,
      start=a,
      is_goal=n => n == goal,
      edge_cost=ew,
      estimate_cost=heuristic_for(goal),
    )
    match (ap, dij.get(goal)) {
      (Some((c, _)), Some(d)) => assert_eq(c, d)
      (None, None) => () // unreachable in both
      _ => fail("astar/dijkstra reachability disagree for node \{i}")
    }
  }
}

///|
/// petgraph test: tests/graph.rs `test_astar_runtime_optimal`
/// A* must not expand more nodes than necessary: edge_cost is called exactly
/// 5 times for this graph (once per relaxed edge), not 6.
test "test_astar_runtime_optimal" {
  // a=0 b=1 c=2 d=3 e=4
  let g = build_wg([(0, 1, 2), (0, 2, 3), (1, 3, 3), (2, 3, 1), (3, 4, 1)])
  let times_called = Ref(0)
  let e = @graph.NodeId::new(4)
  let _ = @algo.astar(
    g,
    start=@graph.NodeId::new(0),
    is_goal=n => n == e,
    edge_cost=fn(ed) {
      times_called.val += 1
      g.edge_weight(ed).unwrap()
    },
    estimate_cost=_ => 0,
  )
  inspect(times_called.val, content="5")
}

///|
/// petgraph test: tests/graph.rs `test_astar_admissible_inconsistent`
test "test_astar_admissible_inconsistent" {
  // a=0 b=1 c=2 d=3
  let g = build_wg([(0, 1, 3), (1, 2, 3), (2, 3, 3), (0, 2, 8), (0, 3, 10)])
  // admissible but inconsistent heuristic: A=9, B=6, C=0, D=0
  let h = fn(n : @graph.NodeId) -> Int {
    match n.index() {
      0 => 9
      1 => 6
      2 => 0
      _ => 0
    }
  }
  let d = @graph.NodeId::new(3)
  let optimal = @algo.astar(
    g,
    start=@graph.NodeId::new(0),
    is_goal=n => n == d,
    edge_cost=wt(g),
    estimate_cost=h,
  )
  guard optimal is Some((cost, p)) else { fail("expected optimal path") }
  inspect(cost, content="9")
  json_inspect([ for n in p => n.index() ], content=[0, 1, 2, 3])
}

///|
/// petgraph doctest: src/algo/bellman_ford.rs `bellman_ford`
test "bellman_ford doctest (distances + predecessors)" {
  // a=0 b=1 c=2 d=3 e=4 f=5, Double weights as in the doctest.
  let g = build_wgf([
    (0, 1, 2.0),
    (0, 3, 4.0),
    (1, 2, 1.0),
    (1, 5, 7.0),
    (2, 4, 5.0),
    (4, 5, 1.0),
    (3, 4, 1.0),
  ])
  let ew = fn(e : @graph.EdgeId) -> Double { g.edge_weight(e).unwrap() }
  let paths = @algo.bellman_ford(g, source=@graph.NodeId::new(0), edge_cost=ew)
  json_inspect([ for d in paths.distances => d.unwrap() ], content=[
    0, 2, 3, 4, 5, 6,
  ])
  // predecessors: [None, Some(a), Some(b), Some(a), Some(d), Some(e)]
  let preds : Array[Int] = []
  for p in paths.predecessors {
    preds.push(
      match p {
        Some(n) => n.index()
        None => -1
      },
    )
  }
  json_inspect(preds, content=[-1, 0, 1, 0, 3, 4])
}

///|
/// petgraph doctest: src/algo/bellman_ford.rs `bellman_ford` (negative cycle)
/// The doctest builds an UNDIRECTED graph with negative weights, which yields a
/// reachable negative cycle (each undirected edge is traversable both ways).
test "bellman_ford doctest (negative cycle is Err)" {
  let g : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
  for _i in 0..<6 {
    g.add_node(g.node_count()) |> ignore
  }
  let edges : Array[(Int, Int, Double)] = [
    (0, 1, -2.0),
    (0, 3, -4.0),
    (1, 2, -1.0),
    (1, 5, -25.0),
    (2, 4, -5.0),
    (4, 5, -25.0),
    (3, 4, -1.0),
  ]
  for e in edges {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  let ew = fn(e : @graph.EdgeId) -> Double { g.edge_weight(e).unwrap() }
  let detected = try
    @algo.bellman_ford(g, source=@graph.NodeId::new(0), edge_cost=ew)
  catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(detected, content="true")
}
