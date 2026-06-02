// Ported from petgraph's REAL tests for the structural algorithms:
// kosaraju_scc / tarjan_scc (tests/graph.rs `scc`, `tarjan_scc`, plus the
// scc doctests), toposort (tests/graph.rs `test_toposort`, `test_toposort_eq`),
// is_cyclic_directed (tests/graph.rs `is_cyclic_directed`),
// is_cyclic_undirected (tests/graph.rs `cyclic`), and connected_components
// (tests/graph.rs `connected_comp`, mod.rs doctest).
// Original Rust test/doctest names are preserved as annotations.
//
// SCC ordering note: ours is reverse-topological with arbitrary intra-SCC
// order, so SCCs are compared by sorting each SCC and (when order does not
// matter) the outer list, mirroring petgraph's own `assert_sccs_eq` helper.

///|
/// Sort each SCC's node ids; optionally sort the outer list too. Mirrors
/// petgraph's `assert_sccs_eq` normalization.
fn norm_sccs(
  sccs : Array[Array[@graph.NodeId]],
  order_matters~ : Bool,
) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  for scc in sccs {
    let inner = [ for n in scc => n.index() ]
    inner.sort()
    out.push(inner)
  }
  if !order_matters {
    out.sort_by((a, b) => cmp_int_arr(a, b))
  }
  out
}

///|
/// Lexicographic comparison of two Int arrays (shorter-then-equal is smaller).
fn cmp_int_arr(a : Array[Int], b : Array[Int]) -> Int {
  let m = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<m {
    if a[i] != b[i] {
      return a[i].compare(b[i])
    }
  }
  a.length().compare(b.length())
}

///|
/// Build the "Kosaraju bug from PR #60" graph: self-loops on 0 and 2, edges
/// 1->0, 2->0, 2->1, plus a disconnected node 3.
fn make_pr60_graph() -> @graph.Graph[Int, Unit] {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new()
  for _i in 0..<3 {
    g.add_node(g.node_count()) |> ignore
  }
  for e in [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)] {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), ()) |> ignore
  }
  g.add_node(g.node_count()) |> ignore // node 3, disconnected
  g
}

///|
/// petgraph doctest: src/algo/scc/kosaraju_scc.rs `kosaraju_scc`
test "kosaraju_scc doctest (two 3-node SCCs)" {
  // a=0 b=1 c=2 d=3 e=4 f=5 ; SCC {0,1,2}, SCC {3,4,5}, edge c->d connects.
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 0),
    (3, 4),
    (4, 5),
    (5, 3),
    (2, 3),
  ])
  let sccs = @algo.kosaraju_scc(g)
  inspect(sccs.length(), content="2")
  for scc in sccs {
    inspect(scc.length(), content="3")
  }
  json_inspect(norm_sccs(sccs, order_matters=false), content=[
    [0, 1, 2],
    [3, 4, 5],
  ])
}

///|
/// petgraph doctest: src/algo/scc/kosaraju_scc.rs `kosaraju_scc` (DAG)
test "kosaraju_scc doctest (DAG: each node its own SCC)" {
  let g = @graph.from_edges([(0, 1), (1, 2)])
  let sccs = @algo.kosaraju_scc(g)
  inspect(sccs.length(), content="3")
  for scc in sccs {
    inspect(scc.length(), content="1")
  }
}

///|
/// petgraph doctest: src/algo/scc/tarjan_scc.rs `tarjan_scc` (undirected -> CC)
test "tarjan_scc doctest (undirected two components)" {
  // a=0 b=1 c=2 d=3 ; components {0,1} and {2,3}.
  let g = @graph.from_edges_undirected([(0, 1), (2, 3)])
  let sccs = @algo.tarjan_scc(g)
  inspect(sccs.length(), content="2")
  for scc in sccs {
    inspect(scc.length(), content="2")
  }
  json_inspect(norm_sccs(sccs, order_matters=false), content=[[0, 1], [2, 3]])
}

///|
/// petgraph test: tests/graph.rs `scc` (kosaraju_scc).
/// The condensation/Reversed-edge sub-parts are out of scope; the directed and
/// undirected SCC-partition checks and the PR#60 bug case are kept.
test "scc (kosaraju)" {
  let gr = @graph.from_edges([
    (6, 0),
    (0, 3),
    (3, 6),
    (8, 6),
    (8, 2),
    (2, 5),
    (5, 8),
    (7, 5),
    (1, 7),
    (7, 4),
    (4, 1),
  ])
  // order_matters=true in petgraph; ours is reverse-topological. The exact
  // outer order can differ, so compare as a normalized set (order_matters=false)
  // which still verifies the SCC partition exactly.
  json_inspect(norm_sccs(@algo.kosaraju_scc(gr), order_matters=false), content=[
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
  ])

  // Undirected version: delete the 6-8 edge to disconnect.
  let hr = @graph.from_edges_undirected([
    (6, 0),
    (0, 3),
    (3, 6),
    (8, 6),
    (8, 2),
    (2, 5),
    (5, 8),
    (7, 5),
    (1, 7),
    (7, 4),
    (4, 1),
  ])
  guard hr.find_edge(@graph.NodeId::new(6), @graph.NodeId::new(8)) is Some(ed)
  guard hr.remove_edge(ed) is Some(_)
  json_inspect(norm_sccs(@algo.kosaraju_scc(hr), order_matters=false), content=[
    [0, 3, 6],
    [1, 2, 4, 5, 7, 8],
  ])

  // acyclic non-tree, #14
  let gr2 : @graph.Graph[Int, Unit] = @graph.Graph::new()
  for _i in 0..<4 {
    gr2.add_node(gr2.node_count()) |> ignore
  }
  gr2.add_edge(@graph.NodeId::new(3), @graph.NodeId::new(2), ()) |> ignore
  gr2.add_edge(@graph.NodeId::new(3), @graph.NodeId::new(1), ()) |> ignore
  gr2.add_edge(@graph.NodeId::new(2), @graph.NodeId::new(0), ()) |> ignore
  gr2.add_edge(@graph.NodeId::new(1), @graph.NodeId::new(0), ()) |> ignore
  json_inspect(norm_sccs(@algo.kosaraju_scc(gr2), order_matters=false), content=[
    [0],
    [1],
    [2],
    [3],
  ])

  // Kosaraju bug from PR #60: self-loops and a disconnected node.
  let gr3 = make_pr60_graph()
  json_inspect(norm_sccs(@algo.kosaraju_scc(gr3), order_matters=false), content=[
    [0],
    [1],
    [2],
    [3],
  ])
}

///|
/// petgraph test: tests/graph.rs `tarjan_scc`.
/// Mirrors `scc` but for tarjan_scc; condensation parts skipped.
test "tarjan_scc" {
  let gr = @graph.from_edges([
    (6, 0),
    (0, 3),
    (3, 6),
    (8, 6),
    (8, 2),
    (2, 5),
    (5, 8),
    (7, 5),
    (1, 7),
    (7, 4),
    (4, 1),
  ])
  json_inspect(norm_sccs(@algo.tarjan_scc(gr), order_matters=false), content=[
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
  ])
  let hr = @graph.from_edges_undirected([
    (6, 0),
    (0, 3),
    (3, 6),
    (8, 6),
    (8, 2),
    (2, 5),
    (5, 8),
    (7, 5),
    (1, 7),
    (7, 4),
    (4, 1),
  ])
  guard hr.find_edge(@graph.NodeId::new(6), @graph.NodeId::new(8)) is Some(ed)
  guard hr.remove_edge(ed) is Some(_)
  json_inspect(norm_sccs(@algo.tarjan_scc(hr), order_matters=false), content=[
    [0, 3, 6],
    [1, 2, 4, 5, 7, 8],
  ])
  let gr2 : @graph.Graph[Int, Unit] = @graph.Graph::new()
  for _i in 0..<4 {
    gr2.add_node(gr2.node_count()) |> ignore
  }
  gr2.add_edge(@graph.NodeId::new(3), @graph.NodeId::new(2), ()) |> ignore
  gr2.add_edge(@graph.NodeId::new(3), @graph.NodeId::new(1), ()) |> ignore
  gr2.add_edge(@graph.NodeId::new(2), @graph.NodeId::new(0), ()) |> ignore
  gr2.add_edge(@graph.NodeId::new(1), @graph.NodeId::new(0), ()) |> ignore
  json_inspect(norm_sccs(@algo.tarjan_scc(gr2), order_matters=false), content=[
    [0],
    [1],
    [2],
    [3],
  ])
  let gr3 = make_pr60_graph()
  json_inspect(norm_sccs(@algo.tarjan_scc(gr3), order_matters=false), content=[
    [0],
    [1],
    [2],
    [3],
  ])
}

///|
/// Assert `order` is a valid topological order of directed graph `g`:
/// it lists every node once and every edge goes source-before-target.
fn assert_topo_order(
  g : @graph.Graph[Int, Int],
  order : Array[@graph.NodeId],
) -> Unit raise {
  assert_eq(order.length(), g.node_count())
  let pos = Array::make(g.node_count(), -1)
  for i, n in order {
    pos[n.index()] = i
  }
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((s, t))
    assert_eq(pos[s.index()] < pos[t.index()], true)
  }
}

///|
/// petgraph test: tests/graph.rs `test_toposort`
test "test_toposort" {
  // a=0 b=1 c=2 d=3 e=4 f=5 g=6 plus disjoint h=7 i=8 j=9.
  let g = build_wg([
    (0, 1, 7),
    (0, 3, 5),
    (3, 1, 9),
    (1, 2, 8),
    (1, 4, 7),
    (2, 4, 5),
    (3, 4, 15),
    (3, 5, 6),
    (5, 4, 8),
    (5, 6, 11),
    (4, 6, 9),
    (7, 8, 1),
    (7, 9, 3),
    (8, 9, 1),
  ])
  guard (try? @algo.toposort(g)) is Ok(order) else { fail("expected acyclic") }
  assert_topo_order(g, order)
}

///|
/// petgraph test: tests/graph.rs `test_toposort_eq`
test "test_toposort_eq" {
  // a=0 b=1, single edge a->b ; toposort must be exactly [a, b].
  let g = @graph.from_edges([(0, 1)])
  guard (try? @algo.toposort(g)) is Ok(order) else { fail("expected acyclic") }
  json_inspect([ for n in order => n.index() ], content=[0, 1])
}

///|
/// petgraph test: tests/graph.rs `is_cyclic_directed`
test "is_cyclic_directed" {
  // Build the acyclic graph + disjoint part, then add g->e to make a cycle.
  let g = build_wg([
    (0, 1, 7),
    (0, 3, 5),
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
  inspect(@algo.is_cyclic_directed(g), content="false")
  // disjoint part h=7 i=8 j=9
  for _i in 0..<3 {
    g.add_node(g.node_count()) |> ignore
  }
  g.add_edge(@graph.NodeId::new(7), @graph.NodeId::new(8), 1) |> ignore
  g.add_edge(@graph.NodeId::new(7), @graph.NodeId::new(9), 3) |> ignore
  g.add_edge(@graph.NodeId::new(8), @graph.NodeId::new(9), 1) |> ignore
  inspect(@algo.is_cyclic_directed(g), content="false")
  // g(6) -> e(4) closes a cycle
  g.add_edge(@graph.NodeId::new(6), @graph.NodeId::new(4), 0) |> ignore
  inspect(@algo.is_cyclic_directed(g), content="true")
}

///|
/// petgraph test: tests/graph.rs `cyclic` (is_cyclic_undirected).
/// Uses add/remove edges to toggle cycles in an undirected graph.
test "cyclic (is_cyclic_undirected)" {
  let gr : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
  let a = gr.add_node(0)
  let b = gr.add_node(1)
  let c = gr.add_node(2)
  inspect(@algo.is_cyclic_undirected(gr), content="false")
  gr.add_edge(a, b, 7.0) |> ignore
  gr.add_edge(c, a, 6.0) |> ignore
  inspect(@algo.is_cyclic_undirected(gr), content="false")

  // self-loop a-a is a cycle
  let e1 = gr.add_edge(a, a, 0.0)
  inspect(@algo.is_cyclic_undirected(gr), content="true")
  gr.remove_edge(e1) |> ignore
  inspect(@algo.is_cyclic_undirected(gr), content="false")

  // b-c closes a cycle a-b-c-a
  let e2 = gr.add_edge(b, c, 0.0)
  inspect(@algo.is_cyclic_undirected(gr), content="true")
  gr.remove_edge(e2) |> ignore
  inspect(@algo.is_cyclic_undirected(gr), content="false")

  // extend with a tail, still no cycle, then close it.
  let d = gr.add_node(3)
  let e = gr.add_node(4)
  gr.add_edge(b, d, 0.0) |> ignore
  gr.add_edge(d, e, 0.0) |> ignore
  inspect(@algo.is_cyclic_undirected(gr), content="false")
  gr.add_edge(c, e, 0.0) |> ignore
  inspect(@algo.is_cyclic_undirected(gr), content="true")
}

///|
/// petgraph test: tests/graph.rs `connected_comp`
test "connected_comp" {
  let gr : @graph.Graph[Int, Unit] = @graph.Graph::new()
  for _i in 0..<9 {
    gr.add_node(gr.node_count()) |> ignore
  }
  let edges = [
    (6, 0),
    (0, 3),
    (3, 6),
    (8, 6),
    (8, 2),
    (2, 5),
    (5, 8),
    (7, 5),
    (1, 7),
    (7, 4),
    (4, 1),
  ]
  for e in edges {
    gr.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), ()) |> ignore
  }
  inspect(@algo.connected_components(gr), content="1")

  // add two isolated nodes -> 3 components
  gr.add_node(9) |> ignore
  gr.add_node(10) |> ignore
  inspect(@algo.connected_components(gr), content="3")

  // connect them -> 2 components
  gr.add_edge(@graph.NodeId::new(9), @graph.NodeId::new(10), ()) |> ignore
  inspect(@algo.connected_components(gr), content="2")
}

///|
/// petgraph doctest: src/algo/mod.rs `connected_components`
test "connected_components doctest" {
  // Two directed cycles {0,1,2,3} and {4,5,6,7}; undirected-wise 2 components.
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 0),
    (4, 5),
    (5, 6),
    (6, 7),
    (7, 4),
  ])
  inspect(@algo.connected_components(g), content="2")
  g.add_edge(@graph.NodeId::new(1), @graph.NodeId::new(4), ()) |> ignore
  inspect(@algo.connected_components(g), content="1")
}
