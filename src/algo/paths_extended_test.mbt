// Ported from petgraph's REAL tests/doctests for the extended weighted
// shortest-path algorithms: floyd_warshall (tests/floyd_warshall.rs),
// johnson (tests/johnson.rs), spfa (tests/spfa.rs and the doctest in
// src/algo/spfa.rs), k_shortest_path (tests/k_shortest_path.rs and the doctest
// in src/algo/k_shortest_path.rs), bidirectional_dijkstra (doctest in
// src/algo/dijkstra.rs and `bidirectional_dijkstra_*` in tests/quickcheck.rs)
// and find_negative_cycle (doctest in src/algo/bellman_ford.rs and
// `test_find_negative_cycle` in tests/quickcheck.rs). Original Rust test names
// are preserved as the MoonBit test names.

///|
/// petgraph's `i32::MAX`: the `BoundedMeasure::max_value()` sentinel that
/// `floyd_warshall` reports for an unreachable pair.
const INF_I32 : Int = 2147483647

///|
/// Build an *undirected* `Graph[Int,Int]` (node weight = its own index) from
/// `(src, dst, weight)` triples, auto-creating nodes `0 ..= max_endpoint`.
fn build_wg_undir(edges : Array[(Int, Int, Int)]) -> @graph.Graph[Int, Int] {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
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
/// Turn an all-pairs result into a dense `n x n` matrix, rendering an absent
/// pair (which is how `johnson` reports "no path") as the same `INF_I32`
/// sentinel `floyd_warshall` stores explicitly. This lets both algorithms be
/// compared against the single expected matrix given in petgraph's tests.
fn dist_matrix(
  res : Map[(@graph.NodeId, @graph.NodeId), Int],
  n : Int,
) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  for i in 0..<n {
    let row : Array[Int] = []
    for j in 0..<n {
      let key = (@graph.NodeId::new(i), @graph.NodeId::new(j))
      row.push(
        match res.get(key) {
          Some(d) => d
          None => INF_I32
        },
      )
    }
    out.push(row)
  }
  out
}

///|
/// Run `spfa` from every node and assemble the same dense matrix, so the
/// per-source expectations of petgraph's `tests/spfa.rs` can be checked in one
/// go. Unreachable (`None`) becomes the `INF_I32` sentinel upstream uses.
fn spfa_matrix(g : @graph.Graph[Int, Int]) -> Array[Array[Int]] raise {
  let n = g.node_count()
  let out : Array[Array[Int]] = []
  for i in 0..<n {
    let paths = @algo.spfa(
      g,
      source=@graph.NodeId::new(i),
      edge_cost=weight_of(g),
    )
    out.push(
      [
        for d in paths.distances => {
          match d {
            Some(x) => x
            None => INF_I32
          }
        }
      ],
    )
  }
  out
}

///|
/// The expected all-pairs matrix of the 8-node unit-weight fixture shared by
/// petgraph's `floyd_warshall_uniform_weight`, `johnson_uniform_weight` and
/// `spfa_uniform_weight`.
///
/// a ----> b ----> e ----> f
/// ^       |       ^       |
/// |       v       |       v
/// d <---- c       h <---- g
fn expected_uniform8() -> Array[Array[Int]] {
  [
    [0, 1, 2, 3, 2, 3, 4, 5],
    [3, 0, 1, 2, 1, 2, 3, 4],
    [2, 3, 0, 1, 4, 5, 6, 7],
    [1, 2, 3, 0, 3, 4, 5, 6],
    [INF_I32, INF_I32, INF_I32, INF_I32, 0, 1, 2, 3],
    [INF_I32, INF_I32, INF_I32, INF_I32, 3, 0, 1, 2],
    [INF_I32, INF_I32, INF_I32, INF_I32, 2, 3, 0, 1],
    [INF_I32, INF_I32, INF_I32, INF_I32, 1, 2, 3, 0],
  ]
}

///|
/// The 8-node unit-weight fixture itself.
fn uniform8() -> @graph.Graph[Int, Int] {
  build_wg([
    (0, 1, 1),
    (1, 2, 1),
    (2, 3, 1),
    (3, 0, 1),
    (4, 5, 1),
    (1, 4, 1),
    (5, 6, 1),
    (6, 7, 1),
    (7, 4, 1),
  ])
}

///|
/// The expected all-pairs matrix of the 4-node weighted directed fixture shared
/// by `floyd_warshall_weighted`, `johnson_weighted`, `spfa_weighted` and the
/// `*_multiple_edges` variants.
fn expected_weighted4() -> Array[Array[Int]] {
  [
    [0, 1, 3, 3],
    [INF_I32, 0, 2, 2],
    [INF_I32, INF_I32, 0, 2],
    [INF_I32, INF_I32, INF_I32, 0],
  ]
}

///|
/// The expected all-pairs matrix of the 4-node weighted *undirected* fixture.
fn expected_undirected4() -> Array[Array[Int]] {
  [[0, 1, 3, 3], [1, 0, 2, 2], [3, 2, 0, 2], [3, 2, 2, 0]]
}

///|
/// The 4-node weighted directed fixture.
fn weighted4() -> @graph.Graph[Int, Int] {
  build_wg([(0, 1, 1), (0, 2, 4), (0, 3, 10), (1, 2, 2), (1, 3, 2), (2, 3, 2)])
}

///|
/// The 4-node weighted undirected fixture.
fn undirected4() -> @graph.Graph[Int, Int] {
  build_wg_undir([
    (0, 1, 1),
    (0, 2, 4),
    (0, 3, 10),
    (1, 3, 2),
    (2, 1, 2),
    (2, 3, 2),
  ])
}

///|
/// The 4-node fixture with parallel edges and a self-loop; its shortest paths
/// are the same as `weighted4`'s.
fn multiple_edges4() -> @graph.Graph[Int, Int] {
  build_wg([
    (0, 1, 10),
    (0, 1, 1),
    (0, 2, 4),
    (0, 3, 10),
    (1, 2, 2),
    (1, 3, 2),
    (2, 3, 2),
    (0, 3, 100),
    (2, 3, 20),
    (0, 0, 5),
  ])
}

///|
/// The 3-node negative cycle `0 ->1-> 1 ->-3-> 2 ->1-> 0` (total weight -1).
fn negative_cycle3() -> @graph.Graph[Int, Int] {
  build_wg([(0, 1, 1), (1, 2, -3), (2, 0, 1)])
}

///|
/// petgraph test: tests/floyd_warshall.rs `floyd_warshall_uniform_weight`
test "floyd_warshall_uniform_weight" {
  let g = uniform8()
  let res = @algo.floyd_warshall(g, edge_cost=_ => 1)
  assert_eq(dist_matrix(res, 8), expected_uniform8())
}

///|
/// petgraph test: tests/floyd_warshall.rs `floyd_warshall_weighted`
test "floyd_warshall_weighted" {
  let g = weighted4()
  let res = @algo.floyd_warshall(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), expected_weighted4())
}

///|
/// petgraph test: tests/floyd_warshall.rs `floyd_warshall_weighted_undirected`
test "floyd_warshall_weighted_undirected" {
  let g = undirected4()
  let res = @algo.floyd_warshall(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), expected_undirected4())
}

///|
/// petgraph test: tests/floyd_warshall.rs `floyd_warshall_negative_cycle`
test "floyd_warshall_negative_cycle" {
  let g = negative_cycle3()
  let detected = try @algo.floyd_warshall(g, edge_cost=weight_of(g)) catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(detected, content="true")
}

///|
/// petgraph test: tests/floyd_warshall.rs `floyd_warshall_multiple_edges`
///
/// Parallel edges keep only the cheapest, and the `0 ->5-> 0` self-loop is
/// overwritten by the zero diagonal.
test "floyd_warshall_multiple_edges" {
  let g = multiple_edges4()
  let res = @algo.floyd_warshall(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), expected_weighted4())
}

///|
/// petgraph doctest: src/algo/floyd_warshall.rs `floyd_warshall`
test "floyd_warshall doctest" {
  // Same graph as `weighted4`, spelled out the way the doctest does.
  let g = build_wg([
    (0, 1, 1),
    (0, 2, 4),
    (0, 3, 10),
    (1, 2, 2),
    (1, 3, 2),
    (2, 3, 2),
  ])
  let res = @algo.floyd_warshall(g, edge_cost=weight_of(g))
  let a = @graph.NodeId::new(0)
  let c = @graph.NodeId::new(2)
  let d = @graph.NodeId::new(3)
  assert_eq(res[(a, c)], 3)
  assert_eq(res[(a, d)], 3)
  assert_eq(res[(d, a)], INF_I32)
}

///|
/// petgraph test: tests/johnson.rs `johnson_uniform_weight`
test "johnson_uniform_weight" {
  let g = uniform8()
  let res = @algo.johnson(g, edge_cost=_ => 1)
  assert_eq(dist_matrix(res, 8), expected_uniform8())
}

///|
/// petgraph test: tests/johnson.rs `johnson_weighted`
test "johnson_weighted" {
  let g = weighted4()
  let res = @algo.johnson(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), expected_weighted4())
}

///|
/// petgraph test: tests/johnson.rs `johnson_weighted_undirected`
test "johnson_weighted_undirected" {
  let g = undirected4()
  let res = @algo.johnson(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), expected_undirected4())
}

///|
/// petgraph test: tests/johnson.rs `johnson_negative_cycle`
test "johnson_negative_cycle" {
  let g = negative_cycle3()
  let detected = try @algo.johnson(g, edge_cost=weight_of(g)) catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(detected, content="true")
}

///|
/// petgraph test: tests/johnson.rs `johnson_multiple_edges`
test "johnson_multiple_edges" {
  let g = multiple_edges4()
  let res = @algo.johnson(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), expected_weighted4())
}

///|
/// petgraph's `johnson` doctest uses the same graph as `johnson_weighted`
/// above, so this extra case exercises what the upstream tests never do:
/// Johnson's reweighting on a genuinely negative edge. `1 ->-2-> 2` is fine
/// because no cycle can exploit it.
test "johnson with negative edges (no negative cycle)" {
  let g = build_wg([(0, 1, 3), (1, 2, -2), (0, 2, 4), (2, 3, 1)])
  let res = @algo.johnson(g, edge_cost=weight_of(g))
  assert_eq(dist_matrix(res, 4), [
    [0, 3, 1, 2],
    [INF_I32, 0, -2, -1],
    [INF_I32, INF_I32, 0, 1],
    [INF_I32, INF_I32, INF_I32, 0],
  ])
}

///|
/// petgraph test: tests/spfa.rs `spfa_uniform_weight`
test "spfa_uniform_weight" {
  let g = uniform8()
  assert_eq(spfa_matrix(g), expected_uniform8())
}

///|
/// petgraph test: tests/spfa.rs `spfa_weighted`
test "spfa_weighted" {
  assert_eq(spfa_matrix(weighted4()), expected_weighted4())
}

///|
/// petgraph test: tests/spfa.rs `spfa_weighted_undirected`
test "spfa_weighted_undirected" {
  assert_eq(spfa_matrix(undirected4()), expected_undirected4())
}

///|
/// petgraph test: tests/spfa.rs `spfa_negative_cycle`
test "spfa_negative_cycle" {
  let g = negative_cycle3()
  // Every source lies on the cycle, so every run must report it.
  for i in 0..<g.node_count() {
    let detected = try
      @algo.spfa(g, source=@graph.NodeId::new(i), edge_cost=weight_of(g))
    catch {
      _ => true
    } noraise {
      _ => false
    }
    assert_true(detected)
  }
}

///|
/// petgraph test: tests/spfa.rs `spfa_multiple_edges`
test "spfa_multiple_edges" {
  assert_eq(spfa_matrix(multiple_edges4()), expected_weighted4())
}

///|
/// petgraph test: tests/spfa.rs `spfa_no_neg_cycle`
///
/// Fails if SPFA uses a stack instead of a queue.
test "spfa_no_neg_cycle" {
  let g = build_wg([
    (0, 4, 1000),
    (0, 3, 100),
    (0, 2, 10),
    (0, 1, 1),
    (3, 4, 100),
    (2, 4, 150),
    (2, 3, 10),
    (1, 4, 111),
    (1, 3, 10),
  ])
  let paths = @algo.spfa(
    g,
    source=@graph.NodeId::new(0),
    edge_cost=weight_of(g),
  )
  // 0 ->1-> 1 ->10-> 3 ->100-> 4 costs 111, tying with 0 ->111-> 4.
  json_inspect([ for d in paths.distances => d.unwrap() ], content=[
    0, 1, 10, 11, 111,
  ])
}

///|
/// petgraph doctest: src/algo/spfa.rs `spfa`
test "spfa doctest" {
  let g = build_wgf([
    (0, 1, 3.0),
    (0, 3, 2.0),
    (1, 2, 1.0),
    (1, 5, 7.0),
    (2, 4, -4.0),
    (3, 4, -1.0),
    (4, 5, 1.0),
  ])
  let paths = @algo.spfa(g, source=@graph.NodeId::new(0), edge_cost=e => {
    g.edge_weight(e).unwrap()
  })
  json_inspect([ for d in paths.distances => d.unwrap() ], content=[
    0, 3, 4, 2, 0, 1,
  ])
  json_inspect(
    [
      for p in paths.predecessors => {
        match p {
          Some(n) => n.index()
          None => -1
        }
      }
    ],
    content=[-1, 0, 1, 0, 2, 4],
  )
}

///|
/// petgraph test: tests/k_shortest_path.rs `second_shortest_path`
test "second_shortest_path" {
  // a=0 b=1 c=2 d=3 e=4 f=5 g=6 h=7 i=8 j=9 k=10 l=11 m=12, unit weights.
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 3),
    (1, 5),
    (5, 6),
    (2, 6),
    (6, 7),
    (3, 4),
    (4, 7),
    (7, 8),
    (7, 9),
    (7, 10),
    (7, 11),
    (8, 12),
    (11, 10),
    (9, 10),
    (9, 12),
    (10, 12),
    (11, 12),
    (12, 4),
  ])
  let res = @algo.k_shortest_path(g, start=@graph.NodeId::new(0), k=2, edge_cost=_ => {
    1
  })
  // Only nodes reachable at least twice appear: e=7 g=3 h=4 i=5 j=5 k=5 l=5 m=6.
  json_inspect(sorted_dist(res), content=[
    [4, 7],
    [6, 3],
    [7, 4],
    [8, 5],
    [9, 5],
    [10, 5],
    [11, 5],
    [12, 6],
  ])
}

///|
/// petgraph doctest: src/algo/k_shortest_path.rs `k_shortest_path`
test "k_shortest_path doctest (2nd shortest from b)" {
  // The same 8-node graph as `uniform8`, plus an isolated node z=8.
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
  g.add_node(8) |> ignore
  let res = @algo.k_shortest_path(g, start=@graph.NodeId::new(1), k=2, edge_cost=_ => {
    1
  })
  // z (8) is absent because there is no path from b to z.
  json_inspect(sorted_dist(res), content=[
    [0, 7],
    [1, 4],
    [2, 5],
    [3, 6],
    [4, 5],
    [5, 6],
    [6, 7],
    [7, 8],
  ])
}

///|
/// `k_shortest_path` with `k = 1` is `dijkstra` (both settle each node the
/// first time it is popped), except that it also records the start node.
test "cross-check: k_shortest_path k=1 == dijkstra" {
  let g = weighted4()
  let src = @graph.NodeId::new(0)
  let ksp = @algo.k_shortest_path(g, start=src, k=1, edge_cost=weight_of(g))
  let dij = @algo.dijkstra(g, start=src, edge_cost=weight_of(g))
  assert_eq(sorted_dist(ksp), sorted_dist(dij))
}

///|
/// petgraph doctest: src/algo/dijkstra.rs `bidirectional_dijkstra`
test "bidirectional_dijkstra doctest" {
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
  let result = @algo.bidirectional_dijkstra(
    g,
    start=@graph.NodeId::new(0),
    goal=@graph.NodeId::new(6),
    edge_cost=_ => 1,
  )
  debug_inspect(result, content="Some(4)")
}

///|
/// petgraph test: tests/quickcheck.rs `bidirectional_dijkstra_directed`
///
/// `bidirectional_dijkstra` must agree with `dijkstra` on every ordered pair of
/// distinct nodes: same reachability, same distance.
test "bidirectional_dijkstra_directed" {
  for g in [uniform8(), weighted4(), multiple_edges4()] {
    let n = g.node_count()
    for i in 0..<n {
      let node1 = @graph.NodeId::new(i)
      let dij = @algo.dijkstra(g, start=node1, edge_cost=weight_of(g))
      for j in 0..<n {
        if i == j {
          continue
        }
        let node2 = @graph.NodeId::new(j)
        let bd = @algo.bidirectional_dijkstra(
          g,
          start=node1,
          goal=node2,
          edge_cost=weight_of(g),
        )
        match (dij.get(node2), bd) {
          (None, None) => ()
          (Some(distance), Some(bidirectional)) =>
            assert_eq(distance, bidirectional)
          // Both algorithms must find a solution for the same problem.
          _ =>
            fail("bidirectional_dijkstra disagrees with dijkstra on \{i}->\{j}")
        }
      }
    }
  }
}

///|
/// petgraph test: tests/quickcheck.rs `bidirectional_dijkstra_undirected`
///
/// Cross-checked against `spfa` rather than `dijkstra`: this package's
/// `dijkstra` follows only the stored edge direction, so it does not traverse
/// an undirected graph both ways.
test "bidirectional_dijkstra_undirected" {
  let g = undirected4()
  let n = g.node_count()
  for i in 0..<n {
    let node1 = @graph.NodeId::new(i)
    let paths = @algo.spfa(g, source=node1, edge_cost=weight_of(g))
    for j in 0..<n {
      if i == j {
        continue
      }
      let bd = @algo.bidirectional_dijkstra(
        g,
        start=node1,
        goal=@graph.NodeId::new(j),
        edge_cost=weight_of(g),
      )
      match (paths.distances[j], bd) {
        (None, None) => ()
        (Some(distance), Some(bidirectional)) =>
          assert_eq(distance, bidirectional)
        _ => fail("bidirectional_dijkstra disagrees with spfa on \{i}->\{j}")
      }
    }
  }
}

///|
/// petgraph doctest: src/algo/bellman_ford.rs `find_negative_cycle`
test "find_negative_cycle doctest" {
  let g = build_wg([
    (0, 1, 1),
    (0, 2, 1),
    (0, 3, 1),
    (1, 3, 1),
    (2, 1, 1),
    (3, 2, -3),
  ])
  let path = @algo.find_negative_cycle(
    g,
    source=@graph.NodeId::new(0),
    edge_cost=weight_of(g),
  )
  guard path is Some(cycle) else { fail("expected a negative cycle") }
  json_inspect([ for n in cycle => n.index() ], content=[1, 3, 2])
}

///|
/// petgraph test: tests/quickcheck.rs `test_find_negative_cycle`
///
/// Whenever a cycle is reported it must be non-empty; the deterministic
/// strengthening here also checks that it really is a cycle of negative total
/// weight.
test "test_find_negative_cycle" {
  let g = negative_cycle3()
  for i in 0..<g.node_count() {
    let path = @algo.find_negative_cycle(
      g,
      source=@graph.NodeId::new(i),
      edge_cost=weight_of(g),
    )
    guard path is Some(cycle) else {
      fail("expected a negative cycle from \{i}")
    }
    assert_true(cycle.length() > 0)
    // Sum the weights around the reported cycle; it must be negative.
    let mut total = 0
    for k in 0..<cycle.length() {
      let a = cycle[k]
      let b = cycle[(k + 1) % cycle.length()]
      guard g.find_edge(a, b) is Some(e) else {
        fail("reported cycle has no edge \{a.index()}->\{b.index()}")
      }
      total = total + g.edge_weight(e).unwrap()
    }
    assert_true(total < 0)
  }
}

///|
/// `find_negative_cycle` returns `None` when there is nothing to find, matching
/// `bellman_ford` succeeding on the same graph.
test "find_negative_cycle returns None without a negative cycle" {
  let g = weighted4()
  let src = @graph.NodeId::new(0)
  let path = @algo.find_negative_cycle(g, source=src, edge_cost=weight_of(g))
  assert_true(path is None)
  let paths = @algo.bellman_ford(g, source=src, edge_cost=weight_of(g))
  json_inspect([ for d in paths.distances => d.unwrap() ], content=[0, 1, 3, 3])
}

///|
/// petgraph test: tests/quickcheck.rs `floyd_warshall_`
///
/// Where `dijkstra` finds a path the distances must agree, and where it does
/// not `floyd_warshall` must report the `max_value()` sentinel.
test "floyd_warshall_" {
  for g in [uniform8(), weighted4(), multiple_edges4()] {
    let n = g.node_count()
    let fw = @algo.floyd_warshall(g, edge_cost=weight_of(g))
    for i in 0..<n {
      let node1 = @graph.NodeId::new(i)
      let dij = @algo.dijkstra(g, start=node1, edge_cost=weight_of(g))
      for j in 0..<n {
        let node2 = @graph.NodeId::new(j)
        let floyd_distance = fw[(node1, node2)]
        match dij.get(node2) {
          Some(distance) => assert_eq(distance, floyd_distance)
          // No path: floyd_warshall saturates at the maximum value.
          None => assert_eq(floyd_distance, INF_I32)
        }
      }
    }
  }
}

///|
/// `johnson` and `floyd_warshall` solve the same problem, so on a graph with
/// negative edges but no negative cycle they must agree on every pair that is
/// actually connected.
///
/// Unreachable pairs are only checked to be saturated, not to be exactly
/// `max_value()`: as in petgraph, relaxing the `max_value()` sentinel by a
/// *negative* edge does not overflow, so `floyd_warshall` can leave an
/// unreachable pair a few units below the sentinel.
test "cross-check: johnson == floyd_warshall" {
  let g = build_wg([
    (0, 1, 3),
    (1, 2, -2),
    (0, 2, 4),
    (2, 3, 1),
    (3, 4, -1),
    (1, 4, 6),
    (4, 5, 2),
  ])
  let n = g.node_count()
  let fw = @algo.floyd_warshall(g, edge_cost=weight_of(g))
  let jh = @algo.johnson(g, edge_cost=weight_of(g))
  for i in 0..<n {
    for j in 0..<n {
      let key = (@graph.NodeId::new(i), @graph.NodeId::new(j))
      match jh.get(key) {
        Some(d) => assert_eq(fw[key], d)
        None => assert_true(fw[key] > INF_I32 / 2)
      }
    }
  }
}

///|
/// `spfa` is a queue-driven `bellman_ford`, so both must agree on distances and
/// on which nodes are reachable, negative edges included.
test "cross-check: spfa == bellman_ford" {
  let g = build_wg([
    (0, 1, 3),
    (1, 2, -2),
    (0, 2, 4),
    (2, 3, 1),
    (3, 4, -1),
    (1, 4, 6),
  ])
  g.add_node(5) |> ignore // unreachable from 0
  let src = @graph.NodeId::new(0)
  let sp = @algo.spfa(g, source=src, edge_cost=weight_of(g))
  let bf = @algo.bellman_ford(g, source=src, edge_cost=weight_of(g))
  for i in 0..<g.node_count() {
    let d_spfa = match sp.distances[i] {
      Some(d) => d
      None => INF_I32
    }
    let d_bf = match bf.distances[i] {
      Some(d) => d
      None => INF_I32
    }
    assert_eq(d_spfa, d_bf)
  }
}

///|
/// On a non-negative graph `spfa` must also agree with `dijkstra`, and
/// `floyd_warshall`'s row for that source must be the same again.
test "cross-check: spfa == dijkstra == floyd_warshall row" {
  let g = weighted4()
  let src = @graph.NodeId::new(0)
  let sp = @algo.spfa(g, source=src, edge_cost=weight_of(g))
  let dij = @algo.dijkstra(g, start=src, edge_cost=weight_of(g))
  let fw = @algo.floyd_warshall(g, edge_cost=weight_of(g))
  for j in 0..<g.node_count() {
    let node = @graph.NodeId::new(j)
    let d_spfa = match sp.distances[j] {
      Some(d) => d
      None => INF_I32
    }
    let d_dij = match dij.get(node) {
      Some(d) => d
      None => INF_I32
    }
    assert_eq(d_spfa, d_dij)
    assert_eq(d_spfa, fw[(src, node)])
  }
}
