// Tests for the connectivity / graph-structure algorithms: articulation_points,
// bridges, dominators (simple_fast), condensation, has_path_connecting and
// is_bipartite_undirected.
//
// The test names are kept from the upstream petgraph test suite
// (`tests/articulation_points.rs`, `tests/graph.rs`, and the in-module
// `bridges.rs` / `dominators.rs` tests).

///|
/// The articulation points of `g` as plain ascending indices.
fn ap_indices(g : @graph.Graph[Int, Unit]) -> Array[Int] {
  [
    for n in @algo.articulation_points(g) => n.index()
  ]
}

///|
/// The `(source, target)` index pairs of the bridges of `g`, in the order
/// `bridges` reports them.
fn bridge_nodes(g : @graph.Graph[Int, Unit]) -> Array[(Int, Int)] {
  let out = []
  for e in @algo.bridges(g) {
    guard! g.edge_endpoints(e) is Some((s, t))
    out.push((s.index(), t.index()))
  }
  out
}

// ---------------------------------------------------------------------------
// articulation_points
// ---------------------------------------------------------------------------

///|
test "art_single_node" {
  let gr : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  let _a = gr.add_node(0)
  json_inspect(ap_indices(gr), content=[])
}

///|
test "art_two_connected_components" {
  // A-B-C and D-E-F: the middle node of each chain is a cut vertex.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (3, 4), (4, 5)])
  json_inspect(ap_indices(gr), content=[1, 4])
}

///|
test "art_linear_chain" {
  // A-B-C-D: both interior nodes are cut vertices.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  json_inspect(ap_indices(gr), content=[1, 2])
}

///|
test "art_star_graph" {
  // Center (node 0) joined to four leaves: only the center is a cut vertex.
  let gr = @graph.from_edges_undirected([(0, 1), (0, 2), (0, 3), (0, 4)])
  json_inspect(ap_indices(gr), content=[0])
}

///|
test "art_clique" {
  // A triangle is biconnected: no articulation points.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 0)])
  json_inspect(ap_indices(gr), content=[])
}

///|
test "art_simple1" {
  // A-B, B-C, B-D: B is the only cut vertex.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (1, 3)])
  json_inspect(ap_indices(gr), content=[1])
}

///|
test "art_disconnected_graph" {
  // A-B-C plus a separate edge D-E: only B cuts anything.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (3, 4)])
  json_inspect(ap_indices(gr), content=[1])
}

///|
test "art_3x3_grid" {
  // A 3x3 grid is biconnected: no articulation points.
  //   A B C     0 1 2
  //   D E F  =  3 4 5
  //   G H I     6 7 8
  let gr = @graph.from_edges_undirected([
    (0, 1),
    (1, 2),
    (0, 3),
    (1, 4),
    (2, 5),
    (3, 4),
    (4, 5),
    (3, 6),
    (4, 7),
    (5, 8),
    (6, 7),
    (7, 8),
  ])
  json_inspect(ap_indices(gr), content=[])
}

///|
test "art_simple2" {
  // A-B, B-C, B-D, D-E: B and D are cut vertices.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (1, 3), (3, 4)])
  json_inspect(ap_indices(gr), content=[1, 3])
}

// ---------------------------------------------------------------------------
// bridges
// ---------------------------------------------------------------------------

///|
test "test_bridges" {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  let n = @graph.NodeId::new
  json_inspect(bridge_nodes(g), content=[])
  let _n0 = g.add_node(0)
  json_inspect(bridge_nodes(g), content=[])
  let _n1 = g.add_node(1)
  json_inspect(bridge_nodes(g), content=[])
  g.add_edge(n(0), n(1), ()) |> ignore
  json_inspect(bridge_nodes(g), content=[[0, 1]])
  let _n2 = g.add_node(2)
  json_inspect(bridge_nodes(g), content=[[0, 1]])
  g.add_edge(n(2), n(1), ()) |> ignore
  json_inspect(bridge_nodes(g), content=[[0, 1], [2, 1]])
  // Closing the triangle 0-1-2 removes both bridges.
  g.add_edge(n(0), n(2), ()) |> ignore
  json_inspect(bridge_nodes(g), content=[])
  let _n3 = g.add_node(3)
  let _n4 = g.add_node(4)
  g.add_edge(n(2), n(3), ()) |> ignore
  g.add_edge(n(3), n(4), ()) |> ignore
  json_inspect(bridge_nodes(g), content=[[2, 3], [3, 4]])
  // 3-0 puts 2-3 on a cycle; the pendant edge 3-4 stays a bridge.
  g.add_edge(n(3), n(0), ()) |> ignore
  json_inspect(bridge_nodes(g), content=[[3, 4]])
}

// ---------------------------------------------------------------------------
// dominators
// ---------------------------------------------------------------------------

///|
test "test_iter_dominators" {
  // 0 -> 1 -> 2, which yields the dominator map {2: 1, 1: 0, 0: 0} of the
  // upstream test.
  let graph = @graph.from_edges([(0, 1), (1, 2)])
  let n = @graph.NodeId::new
  let doms = @algo.simple_fast(graph, n(0))
  guard doms.dominators(n(2)) is Some(all_doms) else {
    fail("node 2 is reachable")
  }
  json_inspect([ for d in all_doms => d.index() ], content=[2, 1, 0])
  assert_true(doms.dominators(n(99)) is None)
  guard doms.strict_dominators(n(2)) is Some(strict_doms) else {
    fail("node 2 is reachable")
  }
  json_inspect([ for d in strict_doms => d.index() ], content=[1, 0])
  assert_true(doms.strict_dominators(n(99)) is None)
  let dom_by = [ for d in doms.immediately_dominated_by(n(1)) => d.index() ]
  json_inspect(dom_by, content=[2])
  assert_true(doms.immediately_dominated_by(n(99)).head() is None)
  assert_eq(doms.immediately_dominated_by(n(0)).count(), 1)
}

///|
test "test_dominators_simple_fast" {
  // The flowgraph of figures 1 and 2 of "A Fast Algorithm for Finding
  // Dominators in a Flowgraph" by Lengauer et al.
  //
  // Expected dominator tree:
  //
  //     r
  //     |-- a
  //     |-- b
  //     |-- c
  //     |   |-- f
  //     |   `-- g
  //     |       `-- j
  //     |-- d
  //     |   `-- l
  //     |-- e
  //     |-- i
  //     |-- k
  //     `-- h
  let graph : @graph.Graph[String, Unit] = @graph.Graph::new()
  let names = ["r", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]
  for name in names {
    graph.add_node(name) |> ignore
  }
  let r = @graph.NodeId::new(0)
  let a = @graph.NodeId::new(1)
  let b = @graph.NodeId::new(2)
  let c = @graph.NodeId::new(3)
  let d = @graph.NodeId::new(4)
  let e = @graph.NodeId::new(5)
  let f = @graph.NodeId::new(6)
  let g = @graph.NodeId::new(7)
  let h = @graph.NodeId::new(8)
  let i = @graph.NodeId::new(9)
  let j = @graph.NodeId::new(10)
  let k = @graph.NodeId::new(11)
  let l = @graph.NodeId::new(12)
  let edges = [
    (r, a),
    (r, b),
    (r, c),
    (a, d),
    (b, a),
    (b, d),
    (b, e),
    (c, f),
    (c, g),
    (d, l),
    (e, h),
    (f, i),
    (g, i),
    (g, j),
    (h, e),
    (h, k),
    (i, k),
    (j, i),
    (k, r),
    (k, i),
    (l, h),
  ]
  for edge in edges {
    graph.add_edge(edge.0, edge.1, ()) |> ignore
  }
  let doms = @algo.simple_fast(graph, r)
  assert_eq(doms.root(), r)
  // The root node has no idom.
  assert_eq(doms.immediate_dominator(r), None)
  assert_eq(doms.immediate_dominator(a), Some(r))
  assert_eq(doms.immediate_dominator(b), Some(r))
  assert_eq(doms.immediate_dominator(c), Some(r))
  assert_eq(doms.immediate_dominator(f), Some(c))
  assert_eq(doms.immediate_dominator(g), Some(c))
  assert_eq(doms.immediate_dominator(j), Some(g))
  assert_eq(doms.immediate_dominator(d), Some(r))
  assert_eq(doms.immediate_dominator(l), Some(d))
  assert_eq(doms.immediate_dominator(e), Some(r))
  assert_eq(doms.immediate_dominator(i), Some(r))
  assert_eq(doms.immediate_dominator(k), Some(r))
  assert_eq(doms.immediate_dominator(h), Some(r))
  // Nodes that aren't reachable from the root do not have an idom.
  let z = graph.add_node("z")
  let doms = @algo.simple_fast(graph, r)
  assert_eq(doms.immediate_dominator(z), None)
  assert_true(doms.dominators(z) is None)
}

// ---------------------------------------------------------------------------
// condensation
// ---------------------------------------------------------------------------

///|
test "condensation" {
  let gr = @graph.from_edges([
    (6, 0),
    (0, 3),
    (3, 6),
    (8, 6),
    (8, 2),
    (2, 3),
    (2, 5),
    (5, 8),
    (7, 5),
    (1, 7),
    (7, 4),
    (4, 1),
  ])
  // make_acyclic = true
  let cond = @algo.condensation(gr, true)
  assert_eq(cond.node_count(), 3)
  assert_eq(cond.edge_count(), 2)
  assert_eq(@algo.is_cyclic_directed(cond), false)
  // The three SCCs are {0,3,6}, {2,5,8} and {1,4,7}; every original node weight
  // ends up in exactly one bucket.
  let sizes : Array[Int] = []
  for nx in cond.node_ids() {
    sizes.push(cond.node_weight(nx).unwrap().length())
  }
  json_inspect(sizes, content=[3, 3, 3])
  // make_acyclic = false keeps every edge, self-loops included.
  let cond = @algo.condensation(gr, false)
  assert_eq(cond.node_count(), 3)
  assert_eq(cond.edge_count(), gr.edge_count())
}

///|
test "condensation preserves undirected graphs" {
  // Undirected: each connected component becomes one node.
  let gr = @graph.from_edges_undirected([(0, 1), (1, 2), (3, 4)])
  let cond = @algo.condensation(gr, true)
  assert_eq(cond.is_directed(), false)
  assert_eq(cond.node_count(), 2)
  assert_eq(cond.edge_count(), 0)
}

// ---------------------------------------------------------------------------
// has_path_connecting
// ---------------------------------------------------------------------------

///|
test "test_has_path" {
  // This is a DAG (plus one back edge b -> a), visited in order.
  let gr : @graph.Graph[String, Double] = @graph.Graph::new()
  let b = gr.add_node("B")
  let a = gr.add_node("A")
  let c = gr.add_node("C")
  let d = gr.add_node("D")
  let e = gr.add_node("E")
  let f = gr.add_node("F")
  let g = gr.add_node("G")
  gr.add_edge(a, b, 7.0) |> ignore
  gr.add_edge(a, d, 5.0) |> ignore
  gr.add_edge(d, b, 9.0) |> ignore
  gr.add_edge(b, c, 8.0) |> ignore
  gr.add_edge(b, e, 7.0) |> ignore
  gr.add_edge(c, e, 5.0) |> ignore
  gr.add_edge(d, e, 15.0) |> ignore
  gr.add_edge(d, f, 6.0) |> ignore
  gr.add_edge(f, e, 8.0) |> ignore
  gr.add_edge(f, g, 11.0) |> ignore
  gr.add_edge(e, g, 9.0) |> ignore
  // Disconnected island.
  let h = gr.add_node("H")
  let i = gr.add_node("I")
  gr.add_edge(h, i, 2.0) |> ignore
  gr.add_edge(i, h, -2.0) |> ignore
  let state = @visit.Dfs::empty(gr)
  gr.add_edge(b, a, 99.0) |> ignore
  assert_true(@algo.has_path_connecting(gr, c, c))
  for edge in gr.edge_ids() {
    guard! gr.edge_endpoints(edge) is Some((src, dst))
    assert_true(@algo.has_path_connecting(gr, src, dst))
  }
  assert_true(@algo.has_path_connecting(gr, a, g, space=state))
  assert_true(!@algo.has_path_connecting(gr, a, h, space=state))
  assert_true(@algo.has_path_connecting(gr, a, c))
  assert_true(@algo.has_path_connecting(gr, a, c, space=state))
  assert_true(!@algo.has_path_connecting(gr, h, a, space=state))
}

// ---------------------------------------------------------------------------
// is_bipartite_undirected
// ---------------------------------------------------------------------------

///|
test "bipartite" {
  {
    let gr : @graph.Graph[String, Double] = @graph.Graph::new_undirected()
    let a = gr.add_node("A")
    let b = gr.add_node("B")
    let c = gr.add_node("C")
    let d = gr.add_node("D")
    let e = gr.add_node("E")
    let f = gr.add_node("F")
    gr.add_edge(a, d, 7.0) |> ignore
    gr.add_edge(b, d, 6.0) |> ignore
    assert_true(@algo.is_bipartite_undirected(gr, a))
    let e_index = gr.add_edge(a, b, 6.0)
    // a-b joins two nodes of the same side.
    assert_true(!@algo.is_bipartite_undirected(gr, a))
    gr.remove_edge(e_index) |> ignore
    assert_true(@algo.is_bipartite_undirected(gr, a))
    gr.add_edge(b, e, 7.0) |> ignore
    gr.add_edge(b, f, 6.0) |> ignore
    gr.add_edge(c, e, 6.0) |> ignore
    assert_true(@algo.is_bipartite_undirected(gr, a))
  }
  // Complete bipartite K(5,3) between {a..e} and {f,g,h}.
  let gr : @graph.Graph[String, Double] = @graph.Graph::new_undirected()
  let a = gr.add_node("A")
  let b = gr.add_node("B")
  let c = gr.add_node("C")
  let d = gr.add_node("D")
  let e = gr.add_node("E")
  let f = gr.add_node("F")
  let g = gr.add_node("G")
  let h = gr.add_node("H")
  for left in [a, b, c, d, e] {
    for right in [f, g, h] {
      gr.add_edge(left, right, 6.0) |> ignore
    }
  }
  assert_true(@algo.is_bipartite_undirected(gr, a))
  gr.add_edge(a, b, 6.0) |> ignore
  assert_true(!@algo.is_bipartite_undirected(gr, a))
}
