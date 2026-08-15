// Ported from petgraph's REAL tests: tests/ford_fulkerson.rs, tests/dinics.rs,
// tests/min_spanning_tree.rs (the Prim cases), tests/steiner_trees.rs and the
// `test_easy_tred` unit test of src/algo/tred.rs. Original Rust test names are
// preserved.
//
// API-shape adaptations:
// * petgraph's fixtures use `u8`/`u16`/`u32`/`f32` weights; MoonBit's `Measure`
//   is implemented for `Int` and `Double`, so integral fixtures use `Int` and
//   the `f32` ones are also exercised with `Double`.
// * `steiner_tree` returns the retained edge set instead of a `StableGraph`, so
//   "node count" is derived from the endpoints of those edges.
// * `dag_transitive_reduction_closure` works on arrays of successor lists
//   instead of petgraph's `adj::List`.
// Tests that petgraph only runs on `StableGraph` (removal of nodes/edges) are
// out of scope, since this port has no stable-graph type.

///|
/// Build a directed graph whose node weights are their indices.
fn ft_digraph(
  order : Int,
  edges : Array[(Int, Int, Int)],
) -> @graph.Graph[Int, Int] {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  for i in 0..<order {
    g.add_node(i) |> ignore
  }
  for e in edges {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  g
}

///|
/// Build an undirected graph whose node weights are their indices.
fn ft_ungraph(
  order : Int,
  edges : Array[(Int, Int, Int)],
) -> @graph.Graph[Int, Int] {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  for i in 0..<order {
    g.add_node(i) |> ignore
  }
  for e in edges {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  g
}

///|
/// Check that `flows` is a valid flow: every edge flow is within `[0,
/// capacity]`, every node other than the source and the destination conserves
/// flow, and the net flow out of the source (into the destination) is
/// `max_flow`.
fn ft_conservation_ok(
  g : @graph.Graph[Int, Int],
  flows : Array[Int],
  source : @graph.NodeId,
  destination : @graph.NodeId,
  max_flow : Int,
) -> Bool {
  let net = Array::make(g.node_count(), 0)
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((s, t)) else { return false }
    guard g.edge_weight(e) is Some(cap) else { return false }
    let f = flows[e.index()]
    if f < 0 || f > cap {
      return false
    }
    net[s.index()] = net[s.index()] + f
    net[t.index()] = net[t.index()] - f
  }
  for v in 0..<g.node_count() {
    if v != source.index() && v != destination.index() && net[v] != 0 {
      return false
    }
  }
  net[source.index()] == max_flow && net[destination.index()] == -max_flow
}

///|
/// The maximum-flow fixtures shared by petgraph's `tests/ford_fulkerson.rs` and
/// `tests/dinics.rs`, as `(order, edges, expected max flow)`. In every fixture
/// the source is node `0` and the destination is the last node.
fn ft_max_flow_fixtures() -> Array[(Int, Array[(Int, Int, Int)], Int)] {
  [
    // Example from https://downey.io/blog/max-flow-ford-fulkerson-algorithm-explanation/
    (4, [(0, 1, 3), (0, 2, 2), (1, 2, 5), (1, 3, 2), (2, 3, 3)], 5),
    // Example from https://brilliant.org/wiki/ford-fulkerson-algorithm/
    (
      6,
      [
        (0, 1, 4),
        (0, 2, 3),
        (1, 3, 4),
        (2, 4, 6),
        (3, 2, 3),
        (3, 5, 2),
        (4, 5, 6),
      ],
      7,
    ),
    // Example from https://cp-algorithms.com/graph/edmonds_karp.html
    (
      6,
      [
        (0, 1, 7),
        (0, 2, 4),
        (1, 3, 5),
        (1, 4, 3),
        (2, 1, 3),
        (2, 4, 2),
        (3, 5, 8),
        (4, 3, 3),
        (4, 5, 5),
      ],
      10,
    ),
    // Example from https://www.programiz.com/dsa/ford-fulkerson-algorithm
    // (corrected upstream: the result is 5, not 6)
    (
      6,
      [
        (0, 1, 8),
        (0, 2, 3),
        (1, 3, 9),
        (2, 3, 7),
        (2, 4, 4),
        (3, 5, 2),
        (4, 5, 5),
      ],
      5,
    ),
    // Example from the CLRS book
    (
      6,
      [
        (0, 1, 16),
        (0, 2, 13),
        (1, 2, 10),
        (1, 3, 12),
        (2, 1, 4),
        (2, 4, 14),
        (3, 2, 9),
        (3, 5, 20),
        (4, 3, 7),
        (4, 5, 4),
      ],
      23,
    ),
    // Example from https://medium.com/@jithmisha/solving-the-maximum-flow-problem-with-ford-fulkerson-method-3fccc2883dc7
    (
      6,
      [
        (0, 1, 10),
        (0, 2, 10),
        (1, 2, 2),
        (1, 3, 4),
        (1, 4, 8),
        (2, 4, 9),
        (3, 5, 10),
        (4, 3, 6),
        (4, 5, 10),
      ],
      19,
    ),
    // Example that gives 3 instead of the maximum 4 when backward edges of the
    // residual network are not considered (petgraph's `test_dinics_g`).
    (
      6,
      [
        (0, 1, 2),
        (0, 2, 2),
        (1, 3, 1),
        (1, 4, 2),
        (2, 3, 2),
        (3, 5, 2),
        (4, 5, 2),
      ],
      4,
    ),
  ]
}

///|
/// Run `ford_fulkerson` on fixture `i` and check the flow value and the flow
/// conservation constraints.
fn ft_check_ford_fulkerson(i : Int) -> Unit raise {
  let (order, edges, expected) = ft_max_flow_fixtures()[i]
  let g = ft_digraph(order, edges)
  let source = @graph.NodeId::new(0)
  let destination = @graph.NodeId::new(order - 1)
  let (max_flow, flows) = @algo.ford_fulkerson(g, source~, destination~, edge_cost=e => {
    g.edge_weight(e).unwrap()
  })
  assert_eq(max_flow, expected)
  assert_true(ft_conservation_ok(g, flows, source, destination, max_flow))
}

///|
/// Run `dinics` on fixture `i` and check the flow value and the flow
/// conservation constraints.
fn ft_check_dinics(i : Int) -> Unit raise {
  let (order, edges, expected) = ft_max_flow_fixtures()[i]
  let g = ft_digraph(order, edges)
  let source = @graph.NodeId::new(0)
  let destination = @graph.NodeId::new(order - 1)
  let (max_flow, flows) = @algo.dinics(g, source~, destination~, edge_cost=e => {
    g.edge_weight(e).unwrap()
  })
  assert_eq(max_flow, expected)
  assert_true(ft_conservation_ok(g, flows, source, destination, max_flow))
}

///|
/// petgraph test: tests/ford_fulkerson.rs `test_ford_fulkerson`
test "test_ford_fulkerson" {
  for i in 0..<ft_max_flow_fixtures().length() {
    ft_check_ford_fulkerson(i)
  }
}

///|
/// The `f32` fixtures of petgraph's `test_ford_fulkerson`, run with `Double`
/// weights to exercise the `Double` implementation of `BoundedMeasure`.
test "test_ford_fulkerson (double weights)" {
  for i in [1, 2, 3] {
    let (order, edges, expected) = ft_max_flow_fixtures()[i]
    let g : @graph.Graph[Int, Double] = @graph.Graph::new()
    for k in 0..<order {
      g.add_node(k) |> ignore
    }
    for e in edges {
      g.add_edge(
        @graph.NodeId::new(e.0),
        @graph.NodeId::new(e.1),
        e.2.to_double(),
      )
      |> ignore
    }
    let (max_flow, _) = @algo.ford_fulkerson(
      g,
      source=@graph.NodeId::new(0),
      destination=@graph.NodeId::new(order - 1),
      edge_cost=e => g.edge_weight(e).unwrap(),
    )
    assert_eq(max_flow, expected.to_double())
  }
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_a`
test "test_dinics_a" {
  ft_check_dinics(0)
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_b`
test "test_dinics_b" {
  ft_check_dinics(1)
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_c`
test "test_dinics_c" {
  ft_check_dinics(2)
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_d`
test "test_dinics_d" {
  ft_check_dinics(3)
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_e`
test "test_dinics_e" {
  ft_check_dinics(4)
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_f`
test "test_dinics_f" {
  ft_check_dinics(5)
}

///|
/// petgraph test: tests/dinics.rs `test_dinics_g`
test "test_dinics_g" {
  ft_check_dinics(6)
}

///|
/// `ford_fulkerson` and `dinics` must agree on every fixture: a maximum flow
/// value is unique even though the per-edge flows generally are not.
test "ford_fulkerson and dinics agree" {
  for fx in ft_max_flow_fixtures() {
    let (order, edges, _) = fx
    let g = ft_digraph(order, edges)
    let source = @graph.NodeId::new(0)
    let destination = @graph.NodeId::new(order - 1)
    let (ff_flow, ff_flows) = @algo.ford_fulkerson(g, source~, destination~, edge_cost=e => {
      g.edge_weight(e).unwrap()
    })
    let (dinic_flow, dinic_flows) = @algo.dinics(g, source~, destination~, edge_cost=e => {
      g.edge_weight(e).unwrap()
    })
    assert_eq(ff_flow, dinic_flow)
    assert_true(ft_conservation_ok(g, ff_flows, source, destination, ff_flow))
    assert_true(
      ft_conservation_ok(g, dinic_flows, source, destination, dinic_flow),
    )
  }
}

///|
/// A source that cannot reach the destination carries no flow.
test "max flow with unreachable destination" {
  let g = ft_digraph(4, [(0, 1, 5), (2, 3, 5)])
  let source = @graph.NodeId::new(0)
  let destination = @graph.NodeId::new(3)
  let (ff_flow, _) = @algo.ford_fulkerson(g, source~, destination~, edge_cost=e => {
    g.edge_weight(e).unwrap()
  })
  let (dinic_flow, _) = @algo.dinics(g, source~, destination~, edge_cost=e => {
    g.edge_weight(e).unwrap()
  })
  assert_eq(ff_flow, 0)
  assert_eq(dinic_flow, 0)
}

///|
/// Collect the undirected endpoint pairs (min, max index) of a set of edges.
fn ft_pairs(
  g : @graph.Graph[Int, Int],
  edges : Array[@graph.EdgeId],
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for e in edges {
    guard g.edge_endpoints(e) is Some((s, t)) else { continue }
    let a = s.index()
    let b = t.index()
    if a < b {
      out.push((a, b))
    } else {
      out.push((b, a))
    }
  }
  out
}

///|
/// Whether an edge between `a` and `b` (in either direction) is present.
fn ft_has_pair(pairs : Array[(Int, Int)], a : Int, b : Int) -> Bool {
  let lo = if a < b { a } else { b }
  let hi = if a < b { b } else { a }
  pairs.iter().any(p => p.0 == lo && p.1 == hi)
}

///|
/// Total weight of a set of edges.
fn ft_total_weight(
  g : @graph.Graph[Int, Int],
  edges : Array[@graph.EdgeId],
) -> Int {
  let mut total = 0
  for e in edges {
    guard g.edge_weight(e) is Some(w) else { continue }
    total = total + w
  }
  total
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim`
test "mst_prim" {
  // A=0 B=1 C=2 D=3 E=4 F=5 G=6, weights as in petgraph (scaled to Int).
  let gr = ft_ungraph(7, [
    (1, 0, 7),
    (3, 0, 5),
    (3, 1, 9),
    (1, 2, 8),
    (1, 4, 7),
    (2, 4, 5),
    (3, 4, 15),
    (3, 5, 6),
    (5, 4, 8),
    (5, 6, 11),
    (4, 6, 9),
  ])
  let mst = @algo.min_spanning_tree_prim(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  assert_eq(mst.length(), gr.node_count() - 1)
  let pairs = ft_pairs(gr, mst)
  // check the exact edges are there
  assert_true(ft_has_pair(pairs, 0, 3))
  assert_true(ft_has_pair(pairs, 0, 1))
  assert_true(ft_has_pair(pairs, 3, 5))
  assert_true(ft_has_pair(pairs, 1, 4))
  assert_true(ft_has_pair(pairs, 4, 2))
  assert_true(ft_has_pair(pairs, 4, 6))
  // Kruskal and Prim must agree on the total weight of a connected graph.
  let kruskal = @algo.min_spanning_tree(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  assert_eq(ft_total_weight(gr, mst), ft_total_weight(gr, kruskal))
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_trivial_graph`
test "mst_prim_trivial_graph" {
  let gr = ft_ungraph(2, [(0, 1, 7)])
  let mst = @algo.min_spanning_tree_prim(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  assert_eq(mst.length(), gr.node_count() - 1)
  assert_true(ft_has_pair(ft_pairs(gr, mst), 0, 1))
  assert_eq(gr.edge_weight(mst[0]).unwrap(), 7)
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_graph_without_edges`
test "mst_prim_graph_without_edges" {
  let gr = ft_ungraph(7, [])
  let mst = @algo.min_spanning_tree_prim(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  assert_eq(mst.length(), 0)
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_empty_graph`
test "mst_prim_empty_graph" {
  let gr = ft_ungraph(0, [])
  let mst = @algo.min_spanning_tree_prim(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  assert_eq(mst.length(), 0)
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_test_cases`.
/// The four parametrized cases of `TEST_CASES`, plus a cross-check that Prim
/// and Kruskal return spanning trees of the same total weight.
test "mst_prim_test_cases" {
  let cases : Array[(Int, Array[(Int, Int, Int)], Array[(Int, Int)])] = [
    (
      9,
      [
        (0, 2, 107),
        (0, 3, 24),
        (0, 4, 47),
        (0, 5, 60),
        (0, 6, 98),
        (0, 7, 29),
        (0, 8, 20),
        (1, 2, 62),
        (1, 3, 115),
        (1, 6, 42),
        (1, 7, 117),
        (1, 8, 19),
        (2, 3, 39),
        (2, 4, 12),
        (2, 5, 27),
        (2, 7, 3),
        (2, 8, 66),
        (3, 4, 54),
        (3, 5, 129),
        (3, 6, 18),
        (3, 7, 137),
        (3, 8, 120),
        (4, 5, 9),
        (4, 6, 124),
        (4, 7, 103),
        (4, 8, 7),
        (5, 7, 77),
        (5, 8, 63),
        (6, 7, 130),
        (7, 8, 138),
      ],
      [(2, 7), (4, 8), (4, 5), (2, 4), (3, 6), (1, 8), (0, 8), (0, 3)],
    ),
    (
      10,
      [
        (0, 2, 84),
        (0, 4, 5),
        (0, 5, 17),
        (0, 6, 97),
        (0, 7, 74),
        (0, 8, 16),
        (1, 3, 49),
        (1, 4, 28),
        (1, 8, 51),
        (1, 9, 137),
        (2, 3, 125),
        (2, 4, 87),
        (2, 6, 114),
        (2, 8, 131),
        (3, 4, 136),
        (3, 5, 43),
        (3, 8, 24),
        (3, 9, 112),
        (4, 5, 61),
        (4, 7, 99),
        (4, 8, 63),
        (4, 9, 108),
        (5, 6, 13),
        (5, 7, 9),
        (5, 8, 133),
        (6, 9, 147),
        (7, 8, 10),
        (7, 9, 88),
        (8, 9, 68),
      ],
      [(0, 4), (5, 7), (7, 8), (5, 6), (0, 8), (3, 8), (1, 4), (8, 9), (0, 2)],
    ),
    (
      15,
      [
        (0, 1, 124),
        (0, 3, 126),
        (0, 6, 84),
        (0, 7, 87),
        (0, 9, 93),
        (0, 12, 32),
        (1, 2, 51),
        (1, 4, 144),
        (1, 6, 36),
        (1, 8, 46),
        (1, 9, 8),
        (1, 13, 26),
        (2, 8, 111),
        (3, 4, 114),
        (3, 6, 98),
        (3, 8, 86),
        (3, 9, 73),
        (4, 5, 41),
        (4, 6, 7),
        (4, 8, 82),
        (4, 9, 48),
        (4, 10, 113),
        (4, 11, 54),
        (4, 12, 10),
        (5, 8, 60),
        (5, 13, 34),
        (6, 13, 85),
        (6, 14, 52),
        (7, 8, 74),
        (7, 12, 137),
        (8, 10, 118),
        (8, 12, 69),
        (8, 13, 133),
        (9, 12, 13),
        (10, 12, 65),
        (10, 14, 107),
        (11, 14, 102),
        (12, 13, 140),
        (12, 14, 11),
        (13, 14, 25),
      ],
      [
        (4, 6),
        (1, 9),
        (4, 12),
        (12, 14),
        (9, 12),
        (13, 14),
        (0, 12),
        (5, 13),
        (1, 8),
        (1, 2),
        (4, 11),
        (10, 12),
        (3, 9),
        (7, 8),
      ],
    ),
    (
      20,
      [
        (0, 2, 5),
        (0, 19, 73),
        (0, 12, 3),
        (1, 17, 145),
        (1, 18, 16),
        (1, 3, 125),
        (1, 5, 6),
        (1, 10, 76),
        (1, 11, 13),
        (1, 15, 12),
        (2, 7, 34),
        (2, 9, 118),
        (3, 12, 43),
        (3, 13, 146),
        (4, 7, 31),
        (5, 6, 62),
        (5, 8, 147),
        (6, 14, 66),
        (7, 16, 67),
        (7, 17, 48),
        (7, 10, 93),
        (7, 12, 113),
        (7, 14, 85),
        (8, 16, 40),
        (8, 18, 111),
        (9, 17, 102),
        (10, 16, 128),
        (10, 18, 120),
        (11, 17, 35),
        (11, 18, 88),
        (11, 13, 54),
        (11, 14, 36),
        (12, 16, 148),
        (13, 15, 75),
        (16, 17, 71),
        (16, 18, 10),
      ],
      [
        (0, 12),
        (0, 2),
        (1, 5),
        (16, 18),
        (1, 15),
        (1, 11),
        (1, 18),
        (4, 7),
        (2, 7),
        (11, 17),
        (11, 14),
        (8, 16),
        (3, 12),
        (7, 17),
        (11, 13),
        (5, 6),
        (0, 19),
        (1, 10),
        (9, 17),
      ],
    ),
  ]
  for c in cases {
    let (order, edges, expected) = c
    let gr = ft_ungraph(order, edges)
    let mst = @algo.min_spanning_tree_prim(gr, edge_cost=e => {
      gr.edge_weight(e).unwrap()
    })
    assert_eq(mst.length(), expected.length())
    let pairs = ft_pairs(gr, mst)
    for ex in expected {
      assert_true(ft_has_pair(pairs, ex.0, ex.1))
    }
    let kruskal = @algo.min_spanning_tree(gr, edge_cost=e => {
      gr.edge_weight(e).unwrap()
    })
    assert_eq(ft_total_weight(gr, mst), ft_total_weight(gr, kruskal))
  }
}

///|
/// The nodes touched by a set of edges, in increasing index order.
fn ft_edge_nodes(
  g : @graph.Graph[Int, Int],
  edges : Array[@graph.EdgeId],
) -> Array[Int] {
  let seen = Array::make(g.node_count(), false)
  for e in edges {
    guard g.edge_endpoints(e) is Some((s, t)) else { continue }
    seen[s.index()] = true
    seen[t.index()] = true
  }
  let out : Array[Int] = []
  for v in 0..<g.node_count() {
    if seen[v] {
      out.push(v)
    }
  }
  out
}

///|
/// Whether the subgraph induced by `edges` is connected (as an undirected
/// graph) over the nodes it touches.
fn ft_edges_connected(
  g : @graph.Graph[Int, Int],
  edges : Array[@graph.EdgeId],
) -> Bool {
  let nodes = ft_edge_nodes(g, edges)
  guard nodes.length() > 0 else { return true }
  let adj : Array[Array[Int]] = Array::makei(g.node_count(), _ => [])
  for e in edges {
    guard g.edge_endpoints(e) is Some((s, t)) else { continue }
    adj[s.index()].push(t.index())
    adj[t.index()].push(s.index())
  }
  let seen = Array::make(g.node_count(), false)
  let stack = [nodes[0]]
  seen[nodes[0]] = true
  while stack.pop() is Some(v) {
    for u in adj[v] {
      if !seen[u] {
        seen[u] = true
        stack.push(u)
      }
    }
  }
  nodes.iter().all(v => seen[v])
}

///|
/// Check the invariants petgraph asserts on a Steiner tree: it contains every
/// terminal, it is a tree (`|E| = |V| - 1`), it is connected, and it has the
/// expected total weight.
fn ft_check_steiner(
  g : @graph.Graph[Int, Int],
  terminals : Array[Int],
  expected_weight : Int,
) -> Unit raise {
  let terminal_ids = terminals.map(t => @graph.NodeId::new(t))
  let tree = @algo.steiner_tree(g, terminal_ids, edge_cost=e => {
    g.edge_weight(e).unwrap()
  })
  let nodes = ft_edge_nodes(g, tree)
  for t in terminals {
    assert_true(nodes.contains(t))
  }
  assert_eq(tree.length(), nodes.length() - 1)
  assert_true(ft_edges_connected(g, tree))
  assert_eq(ft_total_weight(g, tree), expected_weight)
}

///|
/// petgraph test: tests/steiner_trees.rs `example_kous_paper`
test "example_kous_paper" {
  // The (6, 7) and (7, 8) weights are 0.5 in Kou's paper; petgraph approximates
  // them with 0 since neither node is a terminal.
  let g = ft_ungraph(9, [
    (0, 1, 20),
    (0, 8, 1),
    (1, 2, 8),
    (1, 5, 1),
    (2, 4, 2),
    (2, 3, 9),
    (3, 4, 2),
    (4, 8, 1),
    (4, 4, 1),
    (5, 6, 1),
    (6, 7, 0),
    (7, 8, 0),
  ])
  ft_check_steiner(g, [0, 1, 2, 3], 8)
}

///|
/// petgraph test: tests/steiner_trees.rs `b01_vienna_test` (case b01 of the
/// Vienna test set B).
test "b01_vienna_test" {
  let g = ft_ungraph(51, [
    (2, 8, 8),
    (2, 21, 7),
    (2, 32, 2),
    (4, 5, 8),
    (7, 29, 7),
    (11, 3, 7),
    (14, 31, 9),
    (17, 6, 7),
    (17, 42, 6),
    (18, 19, 2),
    (18, 28, 1),
    (18, 43, 1),
    (19, 2, 5),
    (20, 7, 3),
    (20, 14, 7),
    (20, 16, 8),
    (20, 27, 2),
    (20, 38, 8),
    (20, 40, 10),
    (20, 48, 2),
    (21, 12, 7),
    (21, 17, 5),
    (21, 18, 10),
    (22, 10, 6),
    (22, 20, 2),
    (22, 21, 2),
    (22, 40, 8),
    (22, 43, 7),
    (25, 34, 4),
    (27, 34, 4),
    (28, 5, 8),
    (28, 24, 5),
    (29, 9, 5),
    (29, 33, 7),
    (30, 5, 4),
    (30, 15, 1),
    (30, 16, 2),
    (33, 35, 3),
    (34, 20, 10),
    (34, 30, 2),
    (36, 2, 8),
    (36, 4, 6),
    (36, 11, 9),
    (36, 39, 7),
    (36, 49, 9),
    (36, 50, 10),
    (40, 15, 10),
    (40, 23, 3),
    (41, 1, 5),
    (41, 22, 8),
    (41, 25, 5),
    (41, 36, 2),
    (41, 44, 7),
    (41, 47, 7),
    (42, 6, 9),
    (42, 46, 10),
    (44, 24, 8),
    (44, 39, 3),
    (45, 26, 6),
    (45, 28, 1),
    (47, 37, 3),
    (47, 45, 10),
    (50, 13, 1),
  ])
  ft_check_steiner(g, [48, 49, 22, 35, 27, 12, 37, 34, 24], 82)
}

///|
/// petgraph test: tests/steiner_trees.rs `b07_vienna_test` (case b07 of the
/// Vienna test set B).
test "b07_vienna_test" {
  let g = ft_ungraph(76, [
    (7, 17, 6),
    (7, 69, 1),
    (8, 25, 10),
    (8, 39, 1),
    (9, 70, 4),
    (15, 2, 3),
    (15, 20, 1),
    (18, 45, 2),
    (18, 74, 7),
    (19, 7, 9),
    (19, 64, 7),
    (22, 34, 5),
    (23, 9, 5),
    (25, 19, 7),
    (26, 72, 6),
    (27, 3, 10),
    (27, 36, 10),
    (27, 40, 3),
    (28, 6, 6),
    (28, 48, 7),
    (28, 63, 9),
    (29, 21, 4),
    (30, 29, 1),
    (30, 41, 8),
    (30, 62, 2),
    (32, 34, 3),
    (32, 74, 9),
    (33, 7, 10),
    (38, 7, 6),
    (38, 54, 8),
    (38, 60, 10),
    (38, 65, 2),
    (39, 2, 6),
    (40, 3, 10),
    (41, 1, 9),
    (41, 21, 7),
    (41, 23, 7),
    (42, 12, 2),
    (42, 30, 2),
    (42, 53, 3),
    (42, 56, 10),
    (42, 74, 1),
    (43, 4, 8),
    (43, 51, 9),
    (43, 54, 5),
    (43, 55, 6),
    (43, 71, 2),
    (44, 10, 1),
    (44, 26, 3),
    (44, 28, 9),
    (44, 36, 4),
    (44, 43, 8),
    (44, 46, 2),
    (44, 57, 2),
    (44, 68, 2),
    (45, 1, 6),
    (46, 49, 10),
    (46, 52, 2),
    (47, 27, 5),
    (47, 38, 5),
    (47, 41, 10),
    (48, 14, 2),
    (48, 22, 7),
    (50, 73, 1),
    (51, 8, 4),
    (51, 15, 7),
    (52, 16, 9),
    (53, 16, 10),
    (54, 66, 6),
    (56, 20, 6),
    (56, 75, 2),
    (57, 58, 9),
    (58, 5, 10),
    (59, 11, 9),
    (60, 18, 5),
    (60, 31, 5),
    (60, 35, 8),
    (60, 61, 1),
    (60, 67, 10),
    (61, 32, 9),
    (61, 37, 9),
    (63, 24, 10),
    (65, 16, 3),
    (65, 33, 2),
    (65, 42, 6),
    (65, 44, 4),
    (65, 50, 1),
    (65, 59, 1),
    (67, 20, 3),
    (67, 39, 6),
    (70, 13, 8),
    (71, 70, 4),
    (72, 9, 1),
    (74, 37, 4),
  ])
  ft_check_steiner(g, [55, 52, 60, 63, 24, 26, 70, 36, 29, 51, 23, 59, 14], 111)
}

///|
/// Reachability (excluding the trivial `v -> v` unless a cycle exists) of every
/// node of an adjacency list, computed with a DFS.
fn ft_reachability(adj : Array[Array[Int]]) -> Array[Array[Bool]] {
  Array::makei(adj.length(), s => {
    let seen = Array::make(adj.length(), false)
    let stack = [s]
    while stack.pop() is Some(v) {
      for u in adj[v] {
        if !seen[u] {
          seen[u] = true
          stack.push(u)
        }
      }
    }
    seen
  })
}

///|
/// petgraph test: src/algo/tred.rs `test_easy_tred`
test "test_easy_tred" {
  // a -> b, a -> c, b -> c, already in topological order.
  let input : Array[Array[Int]] = [[1, 2], [2], []]
  let (tred, tclos) = @algo.dag_transitive_reduction_closure(input)
  assert_eq(tred.length(), 3)
  assert_eq(tclos.length(), 3)
  assert_true(tred[0].contains(1))
  assert_true(tred[1].contains(2))
  assert_true(!tred[0].contains(2))
  assert_true(tclos[0].contains(1))
  assert_true(tclos[1].contains(2))
  assert_true(tclos[0].contains(2))
}

///|
/// petgraph doc example of `dag_to_toposorted_adjacency_list`: the children of
/// `top` are listed in topological order.
test "dag_to_toposorted_adjacency_list" {
  let g : @graph.Graph[String, Unit] = @graph.Graph::new()
  let second = g.add_node("second child")
  let top = g.add_node("top")
  let first = g.add_node("first child")
  g.add_edge(top, second, ()) |> ignore
  g.add_edge(top, first, ()) |> ignore
  g.add_edge(first, second, ()) |> ignore
  let toposort = [top, first, second]
  let (res, revmap) = @algo.dag_to_toposorted_adjacency_list(g, toposort)
  // The children of `top`, mapped back to the original node indices.
  let children = res[revmap[top.index()]].map(ix => toposort[ix].index())
  assert_eq(children, [first.index(), second.index()])
}

///|
/// The transitive reduction of a DAG must have exactly the same reachability as
/// the DAG itself, and the transitive closure must list precisely the reachable
/// nodes.
test "tred preserves reachability" {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new()
  for i in 0..<8 {
    g.add_node(i) |> ignore
  }
  // A DAG with plenty of redundant (transitive) edges.
  for
    e in [
      (0, 1),
      (0, 2),
      (0, 3),
      (1, 3),
      (1, 4),
      (2, 4),
      (2, 5),
      (3, 4),
      (3, 6),
      (4, 6),
      (4, 7),
      (5, 7),
      (6, 7),
      (0, 7),
      (0, 4),
    ] {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), ()) |> ignore
  }
  let order = try! @algo.toposort(g)
  let (adj, revmap) = @algo.dag_to_toposorted_adjacency_list(g, order)
  let (tred, tclos) = @algo.dag_transitive_reduction_closure(adj)
  // Reachability is preserved by the reduction ...
  let reach_input = ft_reachability(adj)
  let reach_tred = ft_reachability(tred)
  assert_eq(reach_input, reach_tred)
  // ... and the closure holds exactly the reachable pairs as direct edges.
  for i in 0..<adj.length() {
    let direct = Array::make(adj.length(), false)
    for j in tclos[i] {
      direct[j] = true
    }
    assert_eq(direct, reach_input[i])
  }
  // The reduction is a subgraph of the input.
  for i in 0..<adj.length() {
    for j in tred[i] {
      assert_true(adj[i].contains(j))
    }
  }
  // `revmap` is the inverse of the topological order.
  for rank, node in order {
    assert_eq(revmap[node.index()], rank)
  }
}
