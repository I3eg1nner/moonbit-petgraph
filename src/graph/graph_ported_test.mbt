// Tests ported from petgraph's crates/petgraph/tests/graph.rs.
// Each test preserves the original Rust function name in its MoonBit test name
// (e.g. `port: undirected`). Only tests exercising the `Graph` API we implement
// are ported; out-of-scope tests (algos, iterators-with-weights, map/filter,
// StableGraph, GraphMap, etc.) are skipped — see the report for the full list.

///|
/// Helper: render a sequence of NodeId as their integer indices.
fn p_node_indices(xs : Iter[@graph.NodeId]) -> Array[Int] {
  [
    for x in xs => x.index()
  ]
}

///|
/// Helper: render a sequence of EdgeId as their integer indices.
fn p_edge_indices(xs : Iter[@graph.EdgeId]) -> Array[Int] {
  [
    for x in xs => x.index()
  ]
}

///|
/// Helper: sorted copy of an Int array (insertion sort, deterministic).
/// petgraph tests that don't care about order call `.sort()` before asserting;
/// we mirror that by sorting both the produced indices and the expected ones.
fn p_sorted(xs : Array[Int]) -> Array[Int] {
  let out = xs.copy()
  out.sort()
  out
}

///|
/// port: undirected
/// Construction of an undirected graph, find_edge symmetry, neighbor list,
/// then remove_node and re-check counts and find_edge.
/// Adapted: petgraph iterates `og.raw_edges()` (out of scope); we iterate
/// `edge_ids()` + `edge_endpoints()` to assert the same find_edge symmetry.
test "port: undirected" {
  let og : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let a = og.add_node(0)
  let b = og.add_node(1)
  let c = og.add_node(2)
  let d = og.add_node(3)
  let _ = og.add_edge(a, b, 0)
  let _ = og.add_edge(a, c, 1)
  let _ = og.add_edge(c, a, 2)
  let _ = og.add_edge(a, a, 3)
  let _ = og.add_edge(b, c, 4)
  let _ = og.add_edge(b, a, 5)
  let _ = og.add_edge(a, d, 6)
  debug_inspect(og.node_count(), content="4")
  debug_inspect(og.edge_count(), content="7")
  assert_true(og.find_edge(a, b) is Some(_))
  assert_true(og.find_edge(d, a) is Some(_))
  assert_true(og.find_edge(a, a) is Some(_))
  // For every edge, find_edge in both directions succeeds (undirected).
  for eid in og.edge_ids() {
    let (s, t) = og.edge_endpoints(eid).unwrap()
    assert_true(og.find_edge(s, t) is Some(_))
    assert_true(og.find_edge(t, s) is Some(_))
  }
  // neighbors of b: edges touching b are (a,b)#0, (b,c)#4, (b,a)#5.
  // Outgoing-list (reverse insertion): #5->a, #0->b? no, #0 src is a so it is in
  // b's incoming list. petgraph yields [a, c, a].
  debug_inspect(p_node_indices(og.neighbors(b)), content="[0, 2, 0]")
  let _ = og.remove_node(a)
  // After removing a, b only connects to c.
  debug_inspect(p_node_indices(og.neighbors(b)), content="[2]")
  debug_inspect(og.node_count(), content="3")
  debug_inspect(og.edge_count(), content="1")
  // a was swap-removed; index a (0) now refers to old d. Re-query by the still
  // valid b<->c edge and confirm a's former incident edges are gone.
  assert_true(og.find_edge(b, c) is Some(_))
}

///|
/// port: selfloop
/// find_edge / find_edge_undirected on a directed graph, including a self-loop,
/// then removing the self-loop.
test "port: selfloop" {
  let gr : @graph.Graph[String, Double] = @graph.Graph::new()
  let a = gr.add_node("A")
  let b = gr.add_node("B")
  let c = gr.add_node("C")
  let _ = gr.add_edge(a, b, 7.0)
  let _ = gr.add_edge(c, a, 6.0)
  let sed = gr.add_edge(a, a, 2.0)
  assert_true(gr.find_edge(a, b) is Some(_))
  assert_true(gr.find_edge(b, a) is None)
  assert_true(gr.find_edge_undirected(b, a) is Some(_))
  assert_true(gr.find_edge(a, a) is Some(_))
  let _ = gr.remove_edge(sed)
  assert_true(gr.find_edge(a, a) is None)
}

///|
/// port: multi
/// Multiple parallel edges between the same pair are all kept.
test "port: multi" {
  let gr : @graph.Graph[String, Unit] = @graph.Graph::new()
  let a = gr.add_node("a")
  let b = gr.add_node("b")
  let _ = gr.add_edge(a, b, ())
  let _ = gr.add_edge(a, b, ())
  debug_inspect(gr.edge_count(), content="2")
}

///|
/// port: update_edge
/// update_edge updates an existing edge's weight (directed: only a->b, so b->a
/// is a new edge), and for undirected treats a-b and b-a as the same edge.
test "port: update_edge" {
  // directed
  let gr : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = gr.add_node("a")
  let b = gr.add_node("b")
  let e = gr.update_edge(a, b, 1)
  let f = gr.update_edge(a, b, 2)
  let _ = gr.update_edge(b, a, 3)
  debug_inspect(gr.edge_count(), content="2")
  debug_inspect(e == f, content="true")
  debug_inspect(gr.edge_weight(f), content="Some(2)")
  // undirected
  let gr2 : @graph.Graph[String, Int] = @graph.Graph::new_undirected()
  let a2 = gr2.add_node("a")
  let b2 = gr2.add_node("b")
  let e2 = gr2.update_edge(a2, b2, 1)
  let f2 = gr2.update_edge(b2, a2, 2)
  debug_inspect(gr2.edge_count(), content="1")
  debug_inspect(e2 == f2, content="true")
  debug_inspect(gr2.edge_weight(f2), content="Some(2)")
}

///|
/// port: without
/// externals: nodes with no edges in a given direction.
test "port: without" {
  // undirected: externals(Outgoing) == nodes with no edges at all == [d]
  let og : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let a = og.add_node(0)
  let b = og.add_node(1)
  let c = og.add_node(2)
  let _d = og.add_node(3)
  let _ = og.add_edge(a, b, 0)
  let _ = og.add_edge(a, c, 1)
  debug_inspect(p_node_indices(og.externals(Outgoing)), content="[3]")
  // directed
  let dg : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = dg.add_node(0)
  let b = dg.add_node(1)
  let c = dg.add_node(2)
  let _d = dg.add_node(3)
  let _ = dg.add_edge(a, b, 0)
  let _ = dg.add_edge(a, c, 1)
  // sources (no incoming): a, d
  debug_inspect(p_node_indices(dg.externals(Incoming)), content="[0, 3]")
  // sinks (no outgoing): b, c, d
  debug_inspect(p_node_indices(dg.externals(Outgoing)), content="[1, 2, 3]")
}

///|
/// port: from_edges
/// Undirected from_edges auto-creates nodes; every node has degree 3 here.
/// Adapted: petgraph uses `neighbors(n).count()`; we use the array length.
test "port: from_edges" {
  let gr = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
  ])
  debug_inspect(gr.node_count(), content="4")
  debug_inspect(gr.edge_count(), content="6")
  debug_inspect(gr.neighbors(@graph.NodeId::new(0)).count(), content="3")
  debug_inspect(gr.neighbors(@graph.NodeId::new(1)).count(), content="3")
  debug_inspect(gr.neighbors(@graph.NodeId::new(2)).count(), content="3")
  debug_inspect(gr.neighbors(@graph.NodeId::new(3)).count(), content="3")
}

///|
/// port: neighbors_selfloops
/// Directed and undirected neighbor sets with self-loops; petgraph sorts before
/// comparing, so order is irrelevant here. We sort both sides.
test "port: neighbors_selfloops" {
  // Directed graph: edges (a,a),(a,b),(c,a),(a,a)
  let gr : @graph.Graph[String, Unit] = @graph.Graph::new()
  let a = gr.add_node("a")
  let b = gr.add_node("b")
  let c = gr.add_node("c")
  let _ = gr.add_edge(a, a, ())
  let _ = gr.add_edge(a, b, ())
  let _ = gr.add_edge(c, a, ())
  let _ = gr.add_edge(a, a, ())
  // out neighbors of a: [a, a, b]
  debug_inspect(p_sorted(p_node_indices(gr.neighbors(a))), content="[0, 0, 1]")
  // in neighbors of a: [a, a, c]
  debug_inspect(
    p_sorted(p_node_indices(gr.neighbors_directed(a, Incoming))),
    content="[0, 0, 2]",
  )
  // undirected neighbors of a: [a, a, b, c]
  debug_inspect(
    p_sorted(p_node_indices(gr.neighbors_undirected(a))),
    content="[0, 0, 1, 2]",
  )
  // edges(a) targets == out neighbors
  let edge_targets : Array[Int] = []
  for eid in gr.edges_directed(a, Outgoing) {
    let (_, t) = gr.edge_endpoints(eid).unwrap()
    edge_targets.push(t.index())
  }
  debug_inspect(p_sorted(edge_targets), content="[0, 0, 1]")

  // Undirected graph: edges (a,a),(a,b),(c,a)
  let gr2 : @graph.Graph[String, Unit] = @graph.Graph::new_undirected()
  let a2 = gr2.add_node("a")
  let b2 = gr2.add_node("b")
  let c2 = gr2.add_node("c")
  let _ = gr2.add_edge(a2, a2, ())
  let _ = gr2.add_edge(a2, b2, ())
  let _ = gr2.add_edge(c2, a2, ())
  // out/in/undirected neighbors of a are all [a, b, c]
  debug_inspect(
    p_sorted(p_node_indices(gr2.neighbors(a2))),
    content="[0, 1, 2]",
  )
  debug_inspect(
    p_sorted(p_node_indices(gr2.neighbors_directed(a2, Incoming))),
    content="[0, 1, 2]",
  )
  debug_inspect(
    p_sorted(p_node_indices(gr2.neighbors_undirected(a2))),
    content="[0, 1, 2]",
  )
}

///|
/// port: neighbor_order
/// Directed graph: neighbors are in LIFO (reverse-insertion) order.
test "port: neighbor_order" {
  let gr : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = gr.add_node("a")
  let b = gr.add_node("b")
  let c = gr.add_node("c")
  let _ = gr.add_edge(a, b, 0)
  let _ = gr.add_edge(a, a, 1)
  let _ = gr.add_edge(c, a, 2)
  let _ = gr.add_edge(a, c, 3)
  let _ = gr.add_edge(c, a, 4)
  let _ = gr.add_edge(b, a, 5)
  // out neighbors of a in LIFO order: [c, a, b]
  debug_inspect(p_node_indices(gr.neighbors(a)), content="[2, 0, 1]")
  // in neighbors of a in LIFO order: [b, c, c, a]
  debug_inspect(
    p_node_indices(gr.neighbors_directed(a, Incoming)),
    content="[1, 2, 2, 0]",
  )
}

///|
/// port: test_neighbors_iteration_order
/// Exact neighbor order for a fixed directed and undirected graph.
test "port: test_neighbors_iteration_order" {
  let gd = @graph.from_edges([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  debug_inspect(
    p_node_indices(gd.neighbors(@graph.NodeId::new(0))),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gd.neighbors(@graph.NodeId::new(1))),
    content="[3, 4]",
  )
  let gu = @graph.from_edges_undirected([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  debug_inspect(
    p_node_indices(gu.neighbors(@graph.NodeId::new(0))),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gu.neighbors(@graph.NodeId::new(1))),
    content="[3, 4, 5, 0]",
  )
}

///|
/// port: test_neighbors_directed_iteration_order
test "port: test_neighbors_directed_iteration_order" {
  let gd = @graph.from_edges([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  debug_inspect(
    p_node_indices(gd.neighbors_directed(@graph.NodeId::new(0), Outgoing)),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gd.neighbors_directed(@graph.NodeId::new(0), Incoming)),
    content="[]",
  )
  debug_inspect(
    p_node_indices(gd.neighbors_directed(@graph.NodeId::new(1), Outgoing)),
    content="[3, 4]",
  )
  debug_inspect(
    p_node_indices(gd.neighbors_directed(@graph.NodeId::new(1), Incoming)),
    content="[5, 0]",
  )
  let gu = @graph.from_edges_undirected([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  debug_inspect(
    p_node_indices(gu.neighbors_directed(@graph.NodeId::new(0), Outgoing)),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gu.neighbors_directed(@graph.NodeId::new(0), Incoming)),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gu.neighbors_directed(@graph.NodeId::new(1), Outgoing)),
    content="[3, 4, 5, 0]",
  )
  debug_inspect(
    p_node_indices(gu.neighbors_directed(@graph.NodeId::new(1), Incoming)),
    content="[3, 4, 5, 0]",
  )
}

///|
/// port: test_neighbors_undirected_iteration_order
test "port: test_neighbors_undirected_iteration_order" {
  let gd = @graph.from_edges([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  debug_inspect(
    p_node_indices(gd.neighbors_undirected(@graph.NodeId::new(0))),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gd.neighbors_undirected(@graph.NodeId::new(1))),
    content="[3, 4, 5, 0]",
  )
  let gu = @graph.from_edges_undirected([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  debug_inspect(
    p_node_indices(gu.neighbors_undirected(@graph.NodeId::new(0))),
    content="[2, 1]",
  )
  debug_inspect(
    p_node_indices(gu.neighbors_undirected(@graph.NodeId::new(1))),
    content="[3, 4, 5, 0]",
  )
}

///|
/// port: test_edges_iteration_order
/// `edges(n)` (== edges_directed(n, Outgoing)) order, identified by the edges'
/// endpoints (we map each edge id to its (src,dst) and compare against the
/// expected adjacency order, equivalent to petgraph's find_edge-based expected).
test "port: test_edges_iteration_order" {
  let gd = @graph.from_edges([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  let e0 : Array[(Int, Int)] = []
  for eid in gd.edges_directed(@graph.NodeId::new(0), Outgoing) {
    let (s, t) = gd.edge_endpoints(eid).unwrap()
    e0.push((s.index(), t.index()))
  }
  debug_inspect(e0, content="[(0, 2), (0, 1)]")
  let e1 : Array[(Int, Int)] = []
  for eid in gd.edges_directed(@graph.NodeId::new(1), Outgoing) {
    let (s, t) = gd.edge_endpoints(eid).unwrap()
    e1.push((s.index(), t.index()))
  }
  debug_inspect(e1, content="[(1, 3), (1, 4)]")
  let gu = @graph.from_edges_undirected([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  // node 0's incident edges: (0,1)#0 and (0,2)#1; LIFO => [1, 0]
  let eids0 = p_edge_indices(gu.edges_directed(@graph.NodeId::new(0), Outgoing))
  debug_inspect(eids0, content="[1, 0]")
  // node 1 incident edges: #0(0,1),#2(1,4),#3(1,3),#4(5,1).
  // outgoing list of 1 (reverse): #3,#2 ; then incoming list (reverse): #4,#0
  let eids1 = p_edge_indices(gu.edges_directed(@graph.NodeId::new(1), Outgoing))
  debug_inspect(eids1, content="[3, 2, 4, 0]")
}

///|
/// port: test_edges_directed_iteration_order
test "port: test_edges_directed_iteration_order" {
  let gd = @graph.from_edges([(0, 1), (0, 2), (1, 4), (1, 3), (5, 1)])
  // outgoing of 0: edges (0,2)#1,(0,1)#0 -> LIFO [1,0]
  debug_inspect(
    p_edge_indices(gd.edges_directed(@graph.NodeId::new(0), Outgoing)),
    content="[1, 0]",
  )
  debug_inspect(
    p_edge_indices(gd.edges_directed(@graph.NodeId::new(0), Incoming)),
    content="[]",
  )
  // outgoing of 1: (1,4)#2,(1,3)#3 -> LIFO [3,2]
  debug_inspect(
    p_edge_indices(gd.edges_directed(@graph.NodeId::new(1), Outgoing)),
    content="[3, 2]",
  )
  // incoming of 1: (0,1)#0,(5,1)#4 -> LIFO [4,0]
  debug_inspect(
    p_edge_indices(gd.edges_directed(@graph.NodeId::new(1), Incoming)),
    content="[4, 0]",
  )
}
