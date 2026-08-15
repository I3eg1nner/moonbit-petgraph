// Tests for the extended `Graph` API: edge references, map / filter_map,
// retain, and the weight / adjacency iterators.
//
// Tests ported from petgraph's `crates/petgraph/tests/graph.rs` keep the
// original Rust function name in the MoonBit test name (`port: <name>`).
// Adaptations are noted per test. Helper names are prefixed `x_` because every
// `*_test.mbt` file in this package shares one namespace.

///|
/// Helper: build a `NodeId` from a raw index (petgraph's `let n = NodeIndex::new`).
fn x_n(i : Int) -> @graph.NodeId {
  @graph.NodeId::new(i)
}

///|
/// Helper: render a sequence of EdgeId as their integer indices.
fn x_edge_indices(xs : Iter[@graph.EdgeId]) -> Array[Int] {
  [
    for x in xs => x.index()
  ]
}

///|
/// Helper: render the ids of a sequence of edge references.
fn[E] x_ref_ids(xs : Iter[@graph.EdgeRef[E]]) -> Array[Int] {
  [
    for r in xs => r.id.index()
  ]
}

///|
/// Helper: render the `(source, target)` pairs of a sequence of edge references.
fn[E] x_ref_endpoints(xs : Iter[@graph.EdgeRef[E]]) -> Array[(Int, Int)] {
  [
    for r in xs => (r.source.index(), r.target.index())
  ]
}

///|
/// Helper: the two directions, as an explicitly typed array.
fn x_directions() -> Array[@graph.Direction] {
  [Outgoing, Incoming]
}

///|
/// Port of petgraph's test-side `assert_graph_consistent`: the index ranges
/// agree with the counts, and every edge is findable from its own endpoints.
fn[N, E] x_assert_graph_consistent(g : @graph.Graph[N, E]) -> Unit raise {
  assert_eq(g.node_count(), g.node_ids().count())
  assert_eq(g.edge_count(), g.edge_ids().count())
  for r in g.edge_references() {
    guard g.find_edge(r.source, r.target) is Some(_) else {
      fail("edge not in graph: \{r.source.index()} -> \{r.target.index()}")
    }
  }
}

///|
/// White-box style invariant check on the intrusive adjacency lists, modelled
/// on `graph_wbtest.mbt`'s `check_invariants` but expressed through the public
/// `first_edge` / `next_edge` accessors:
///
/// - every traversed edge id is in bounds (no dangling link),
/// - each chain terminates (no cycles / no overrun),
/// - the endpoint in the walked direction is the node the walk started from,
/// - every edge occurs exactly once in some outgoing list and exactly once in
///   some incoming list (nothing lost, nothing double-linked).
fn[N, E] x_check_edge_lists(g : @graph.Graph[N, E]) -> Unit raise {
  let m = g.edge_count()
  let seen_out = Array::make(m, 0)
  let seen_in = Array::make(m, 0)
  for i in 0..<g.node_count() {
    let node = x_n(i)
    for d in x_directions() {
      let mut cur = g.first_edge(node, d)
      let mut steps = 0
      while cur is Some(e) {
        let idx = e.index()
        guard idx >= 0 && idx < m else {
          fail("dangling edge id \{idx} in node \{i} dir \{d.index()}")
        }
        guard g.edge_endpoints(e) is Some((s, t)) else {
          fail("edge \{idx} has no endpoints")
        }
        let endpoint = match d {
          Outgoing => s
          Incoming => t
        }
        guard endpoint.index() == i else {
          fail(
            "edge \{idx} endpoint dir \{d.index()} is \{endpoint.index()}, expected \{i}",
          )
        }
        match d {
          Outgoing => seen_out[idx] = seen_out[idx] + 1
          Incoming => seen_in[idx] = seen_in[idx] + 1
        }
        cur = g.next_edge(e, d)
        steps = steps + 1
        guard steps <= m else { fail("cycle in adjacency list of node \{i}") }
      }
    }
  }
  for i in 0..<m {
    guard seen_out[i] == 1 else {
      fail("edge \{i} appears \{seen_out[i]} times in outgoing lists")
    }
    guard seen_in[i] == 1 else {
      fail("edge \{i} appears \{seen_in[i]} times in incoming lists")
    }
  }
}

///|
/// Helper: petgraph's `make_edge_iterator_graph`, parameterized on directedness.
fn x_make_edge_iterator_graph(directed : Bool) -> @graph.Graph[Double, Double] {
  let gr : @graph.Graph[Double, Double] = if directed {
    @graph.Graph::new()
  } else {
    @graph.Graph::new_undirected()
  }
  let a = gr.add_node(0.0)
  let b = gr.add_node(0.0)
  let c = gr.add_node(0.0)
  let d = gr.add_node(0.0)
  let e = gr.add_node(0.0)
  let f = gr.add_node(0.0)
  let g = gr.add_node(0.0)
  let _ = gr.add_edge(a, b, 7.0)
  let _ = gr.add_edge(a, d, 5.0)
  let _ = gr.add_edge(d, b, 9.0)
  let _ = gr.add_edge(b, c, 8.0)
  let _ = gr.add_edge(b, e, 7.0)
  let _ = gr.add_edge(c, c, 8.0)
  let _ = gr.add_edge(c, e, 5.0)
  let _ = gr.add_edge(d, e, 15.0)
  let _ = gr.add_edge(d, f, 6.0)
  let _ = gr.add_edge(f, e, 8.0)
  let _ = gr.add_edge(f, g, 11.0)
  let _ = gr.add_edge(e, g, 9.0)
  gr
}

// ---------------------------------------------------------------------------
// edge_references / edges / edges_connecting
// ---------------------------------------------------------------------------

///|
test "edge_references yields all edges in index order" {
  let g : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = g.add_node("a")
  let b = g.add_node("b")
  let c = g.add_node("c")
  let _ = g.add_edge(a, b, 10)
  let _ = g.add_edge(b, c, 20)
  let _ = g.add_edge(c, a, 30)
  debug_inspect(x_ref_ids(g.edge_references()), content="[0, 1, 2]")
  debug_inspect(
    x_ref_endpoints(g.edge_references()),
    content="[(0, 1), (1, 2), (2, 0)]",
  )
  debug_inspect(
    [
      for r in g.edge_references() => r.weight
    ],
    content="[10, 20, 30]",
  )
  // A single reference renders all four components.
  debug_inspect(
    g.edge_references().to_array()[1],
    content="{ id: EdgeId(1), source: NodeId(1), target: NodeId(2), weight: 20 }",
  )
  debug_inspect(g.edge_references().count(), content="3")
  // Empty graph.
  let e : @graph.Graph[Int, Int] = @graph.Graph::new()
  debug_inspect(x_ref_ids(e.edge_references()), content="[]")
}

///|
/// port: test_edge_iterators_directed
/// Adapted: petgraph compares against `Reversed(&gr)` (the `visit` adaptor,
/// out of scope). We keep the parts that only need `Graph`: `edges(i)` agrees
/// with `edges_directed(i, Outgoing)`, and every yielded reference has a fixed
/// source.
test "port: test_edge_iterators_directed" {
  let gr = x_make_edge_iterator_graph(true)
  for i in 0..<gr.node_count() {
    let node = x_n(i)
    debug_inspect(
      x_ref_ids(gr.edges(node)) ==
      x_edge_indices(gr.edges_directed(node, Outgoing)),
      content="true",
    )
    for r in gr.edges(node) {
      assert_eq(r.source.index(), i)
    }
  }
  // Concretely, for node b (index 1): outgoing edges #4 (b,e) and #3 (b,c).
  debug_inspect(x_ref_ids(gr.edges(x_n(1))), content="[4, 3]")
  debug_inspect(x_ref_endpoints(gr.edges(x_n(1))), content="[(1, 4), (1, 2)]")
  // The self-loop on c (index 2) is listed once by `edges`.
  debug_inspect(x_ref_ids(gr.edges(x_n(2))), content="[6, 5]")
}

///|
/// port: test_edge_iterators_undir
/// Adapted the same way as `test_edge_iterators_directed`.
test "port: test_edge_iterators_undir" {
  let gr = x_make_edge_iterator_graph(false)
  for i in 0..<gr.node_count() {
    let node = x_n(i)
    debug_inspect(
      x_ref_ids(gr.edges(node)) ==
      x_edge_indices(gr.edges_directed(node, Outgoing)),
      content="true",
    )
    // For an undirected graph the endpoints are swapped as needed so that the
    // queried node is always the source.
    for r in gr.edges(node) {
      assert_eq(r.source.index(), i)
    }
  }
  // Node b (index 1) is incident to #0 (a,b), #2 (d,b), #3 (b,c), #4 (b,e):
  // outgoing list first (LIFO), then the incoming list (LIFO).
  debug_inspect(x_ref_ids(gr.edges(x_n(1))), content="[4, 3, 2, 0]")
  debug_inspect(
    x_ref_endpoints(gr.edges(x_n(1))),
    content="[(1, 4), (1, 2), (1, 3), (1, 0)]",
  )
  // The self-loop on c (index 2) is still listed exactly once.
  debug_inspect(x_ref_ids(gr.edges(x_n(2))), content="[6, 5, 3]")
}

///|
/// port: test_edges_connecting_iteration_order
test "port: test_edges_connecting_iteration_order" {
  let g : @graph.Graph[Unit, Int] = @graph.Graph::new()
  let node_zero = g.add_node(())
  let node_one = g.add_node(())
  // Edges from node_zero to node_one, then from node_one to node_zero.
  let _ = g.add_edge(node_zero, node_one, 1)
  let _ = g.add_edge(node_zero, node_one, 2)
  let _ = g.add_edge(node_zero, node_one, 3)
  let _ = g.add_edge(node_one, node_zero, 4)
  let _ = g.add_edge(node_one, node_zero, 5)
  let _ = g.add_edge(node_one, node_zero, 6)
  debug_inspect(
    x_edge_indices(g.edges_connecting(node_zero, node_one)),
    content="[2, 1, 0]",
  )
  debug_inspect(
    x_edge_indices(g.edges_connecting(node_one, node_zero)),
    content="[5, 4, 3]",
  )
  let u : @graph.Graph[Unit, Int] = @graph.Graph::new_undirected()
  let uz = u.add_node(())
  let uo = u.add_node(())
  let _ = u.add_edge(uz, uo, 1)
  let _ = u.add_edge(uz, uo, 2)
  let _ = u.add_edge(uz, uo, 3)
  let _ = u.add_edge(uo, uz, 4)
  let _ = u.add_edge(uo, uz, 5)
  let _ = u.add_edge(uo, uz, 6)
  debug_inspect(
    x_edge_indices(u.edges_connecting(uz, uo)),
    content="[2, 1, 0, 5, 4, 3]",
  )
  debug_inspect(
    x_edge_indices(u.edges_connecting(uo, uz)),
    content="[5, 4, 3, 2, 1, 0]",
  )
}

///|
/// port: iter_multi_edges
/// Directed: `edges_connecting(a, b)` finds exactly the two parallel a->b
/// edges, skipping the self-loop and the unrelated edges.
test "port: iter_multi_edges" {
  let gr : @graph.Graph[String, Unit] = @graph.Graph::new()
  let a = gr.add_node("a")
  let b = gr.add_node("b")
  let c = gr.add_node("c")
  let _ = gr.add_edge(a, a, ())
  let e1 = gr.add_edge(a, b, ())
  let _ = gr.add_edge(a, c, ())
  let _ = gr.add_edge(c, b, ())
  let e4 = gr.add_edge(a, b, ())
  let _ = gr.add_edge(b, a, ())
  let found = x_edge_indices(gr.edges_connecting(a, b))
  debug_inspect(found, content="[4, 1]")
  debug_inspect([e4.index(), e1.index()], content="[4, 1]")
}

///|
/// port: iter_multi_undirected_edges
/// Undirected: the `b -> a` edge also connects a and b, and the self-loop on a
/// is still excluded.
test "port: iter_multi_undirected_edges" {
  let gr : @graph.Graph[String, Unit] = @graph.Graph::new_undirected()
  let a = gr.add_node("a")
  let b = gr.add_node("b")
  let c = gr.add_node("c")
  let _ = gr.add_edge(a, a, ())
  let _ = gr.add_edge(a, b, ())
  let _ = gr.add_edge(a, c, ())
  let _ = gr.add_edge(c, b, ())
  let _ = gr.add_edge(a, b, ())
  let _ = gr.add_edge(b, a, ())
  debug_inspect(x_edge_indices(gr.edges_connecting(a, b)), content="[4, 1, 5]")
  debug_inspect(gr.edges_connecting(a, b).count(), content="3")
  // No edge connects b and... itself.
  debug_inspect(x_edge_indices(gr.edges_connecting(b, b)), content="[]")
}

// ---------------------------------------------------------------------------
// map / filter_map
// ---------------------------------------------------------------------------

///|
/// port: test_map
test "port: test_map" {
  let g : @graph.Graph[String, Int] = @graph.Graph::new_undirected()
  let a = g.add_node("A")
  let b = g.add_node("B")
  let c = g.add_node("C")
  let ab = g.add_edge(a, b, 7)
  let bc = g.add_edge(b, c, 14)
  let ca = g.add_edge(c, a, 9)
  let g2 = g.map((_, name) => "map-" + name, (_, weight) => weight * 2)
  debug_inspect(g2.node_count(), content="3")
  debug_inspect(
    g2.node_weight(a),
    content=(
      #|Some("map-A")
    ),
  )
  debug_inspect(
    g2.node_weight(b),
    content=(
      #|Some("map-B")
    ),
  )
  debug_inspect(
    g2.node_weight(c),
    content=(
      #|Some("map-C")
    ),
  )
  debug_inspect(g2.edge_count(), content="3")
  debug_inspect(g2.edge_weight(ab), content="Some(14)")
  debug_inspect(g2.edge_weight(bc), content="Some(28)")
  debug_inspect(g2.edge_weight(ca), content="Some(18)")
  // The structure, directedness and adjacency order are preserved.
  debug_inspect(g2.is_directed(), content="false")
  assert_eq(
    x_edge_indices(g2.edges_directed(b, Outgoing)),
    x_edge_indices(g.edges_directed(b, Outgoing)),
  )
  x_check_edge_lists(g2)
  x_assert_graph_consistent(g2)
  // The original graph is untouched.
  debug_inspect(g.edge_weight(ab), content="Some(7)")
  // The node/edge index arguments are the original ones.
  let ids : Array[Int] = []
  let _ = g.map((i, _) => ids.push(i.index()), (_, w) => w)
  debug_inspect(ids, content="[0, 1, 2]")
}

///|
/// port: test_filter_map
test "port: test_filter_map" {
  let g : @graph.Graph[String, Int] = @graph.Graph::new_undirected()
  let a = g.add_node("A")
  let b = g.add_node("B")
  let c = g.add_node("C")
  let d = g.add_node("D")
  let e = g.add_node("E")
  let f = g.add_node("F")
  let _ = g.add_edge(a, b, 7)
  let _ = g.add_edge(c, a, 9)
  let _ = g.add_edge(a, d, 14)
  let _ = g.add_edge(b, c, 10)
  let _ = g.add_edge(d, c, 2)
  let _ = g.add_edge(d, e, 9)
  let _ = g.add_edge(b, f, 15)
  let _ = g.add_edge(c, f, 11)
  let _ = g.add_edge(e, f, 6)

  // Keep every node, drop the light edges.
  let g2 = g.filter_map((_, name) => Some(name), (_, weight) => {
    if weight >= 10 {
      Some(weight)
    } else {
      None
    }
  })
  debug_inspect(g2.edge_count(), content="4")
  for w in g2.edge_weights() {
    assert_true(w >= 10)
  }
  debug_inspect(g2.node_count(), content="6")
  // Node indices are compatible with the original graph.
  for i in g.node_ids() {
    assert_eq(g2.node_weight(i), g.node_weight(i))
  }
  x_check_edge_lists(g2)
  x_assert_graph_consistent(g2)

  // Drop nodes a and e; edge_map must not see edges touching them.
  // (The closure cannot raise, so violations are recorded and asserted after.)
  let touched_removed : Array[Int] = []
  let g3 = g.filter_map(
    (i, name) => if i == a || i == e { None } else { Some(name) },
    (i, weight) => {
      let (source, target) = g.edge_endpoints(i).unwrap()
      if source == a || target == a || source == e || target == e {
        touched_removed.push(i.index())
      }
      Some(weight)
    },
  )
  debug_inspect(touched_removed, content="[]")
  debug_inspect(g3.node_count(), content="4")
  debug_inspect(g3.edge_count(), content="4")
  x_assert_graph_consistent(g3)
  x_check_edge_lists(g3)
  // Renumbering: B,C,D,F become 0,1,2,3.
  debug_inspect(
    [
      for w in g3.node_weights() => w
    ],
    content=(
      #|["B", "C", "D", "F"]
    ),
  )

  // The same subgraph via retain_edges on a copy (petgraph's `g4`).
  let g4 = g.map((_, w) => w, (_, w) => w)
  g4.retain_edges((gr, i) => {
    let (s, t) = gr.edge_endpoints(i).unwrap()
    !(s == a || s == e || t == a || t == e)
  })
  debug_inspect(g4.edge_count(), content="4")
  x_assert_graph_consistent(g4)
  x_check_edge_lists(g4)
}

///|
test "filter_map dropping everything yields an empty graph" {
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 0)])
  let empty : @graph.Graph[Int, Unit] = g.filter_map((_, _) => None, (_, w) => {
    Some(w)
  })
  debug_inspect(empty.node_count(), content="0")
  debug_inspect(empty.edge_count(), content="0")
  // Dropping only edges keeps every node.
  let no_edges : @graph.Graph[Int, Unit] = g.filter_map((_, w) => Some(w), (
    _,
    _,
  ) => None)
  debug_inspect(no_edges.node_count(), content="3")
  debug_inspect(no_edges.edge_count(), content="0")
  x_check_edge_lists(no_edges)
}

// ---------------------------------------------------------------------------
// retain
// ---------------------------------------------------------------------------

///|
/// port: retain
/// `retain_edges` with a visitor that also mutates node and edge weights.
/// Adapted: petgraph builds the graph with the weighted `from_edges`; we use
/// `extend_with_edges` (node weights default to 0, as `i32::default()` does).
test "port: retain" {
  let gr : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  gr.extend_with_edges([
    (x_n(0), x_n(1), 2),
    (x_n(1), x_n(1), 1),
    (x_n(0), x_n(2), 0),
    (x_n(1), x_n(2), 3),
    (x_n(2), x_n(3), 3),
  ])
  debug_inspect(gr.node_count(), content="4")
  debug_inspect(gr.edge_count(), content="5")
  gr.retain_edges((g, i) => {
    let w = g.edge_weight(i).unwrap()
    if w <= 0 {
      false
    } else {
      let w2 = w - 1
      g.set_edge_weight(i, w2)
      let (s, t) = g.edge_endpoints(i).unwrap()
      g.set_node_weight(s, g.node_weight(s).unwrap() + 1)
      g.set_node_weight(t, g.node_weight(t).unwrap() + 1)
      w2 > 0
    }
  })
  debug_inspect(gr.edge_count(), content="3")
  debug_inspect(gr.node_weight(x_n(0)), content="Some(1)")
  debug_inspect(gr.node_weight(x_n(1)), content="Some(4)")
  debug_inspect(gr.node_weight(x_n(2)), content="Some(2)")
  debug_inspect(gr.node_weight(x_n(3)), content="Some(1)")
  assert_true(gr.find_edge(x_n(1), x_n(1)) is None)
  assert_true(gr.find_edge(x_n(0), x_n(2)) is None)
  x_assert_graph_consistent(gr)
  x_check_edge_lists(gr)
}

///|
test "retain_edges keeps invariants on a directed multigraph" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let d = g.add_node(3)
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, c, 1)
  let _ = g.add_edge(c, d, 2)
  let _ = g.add_edge(d, a, 3)
  let _ = g.add_edge(a, c, 4)
  let _ = g.add_edge(a, a, 5)
  let _ = g.add_edge(b, c, 6)
  // Keep only the even-weighted edges.
  g.retain_edges((gr, e) => gr.edge_weight(e).unwrap() % 2 == 0)
  debug_inspect(g.edge_count(), content="4")
  debug_inspect(
    [ for w in g.edge_weights() => w ].copy()..sort(),
    content="[0, 2, 4, 6]",
  )
  x_check_edge_lists(g)
  x_assert_graph_consistent(g)
  // Removing everything is fine too.
  g.retain_edges((_, _) => false)
  debug_inspect(g.edge_count(), content="0")
  debug_inspect(g.node_count(), content="4")
  x_check_edge_lists(g)
}

///|
test "retain_nodes removes nodes with their incident edges" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let d = g.add_node(3)
  let e = g.add_node(4)
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, c, 1)
  let _ = g.add_edge(c, d, 2)
  let _ = g.add_edge(d, e, 3)
  let _ = g.add_edge(e, a, 4)
  let _ = g.add_edge(a, c, 5)
  // Keep the even-weighted nodes: 0, 2, 4.
  g.retain_nodes((gr, n) => gr.node_weight(n).unwrap() % 2 == 0)
  debug_inspect(g.node_count(), content="3")
  debug_inspect(
    [ for w in g.node_weights() => w ].copy()..sort(),
    content="[0, 2, 4]",
  )
  // Only a->c and e->a survive (both endpoints kept).
  debug_inspect(g.edge_count(), content="2")
  x_check_edge_lists(g)
  x_assert_graph_consistent(g)
  // Keeping everything is a no-op; dropping everything empties the graph.
  g.retain_nodes((_, _) => true)
  debug_inspect(g.node_count(), content="3")
  x_check_edge_lists(g)
  g.retain_nodes((_, _) => false)
  debug_inspect(g.node_count(), content="0")
  debug_inspect(g.edge_count(), content="0")
  x_check_edge_lists(g)
}

///|
test "retain_nodes on an undirected graph with self-loops" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let d = g.add_node(3)
  let _ = g.add_edge(a, a, 0)
  let _ = g.add_edge(a, b, 1)
  let _ = g.add_edge(b, c, 2)
  let _ = g.add_edge(c, c, 3)
  let _ = g.add_edge(c, d, 4)
  let _ = g.add_edge(d, a, 5)
  x_check_edge_lists(g)
  // Drop b: its two incident edges go away; d is swapped into b's slot.
  g.retain_nodes((gr, n) => gr.node_weight(n).unwrap() != 1)
  debug_inspect(g.node_count(), content="3")
  debug_inspect(g.edge_count(), content="4")
  x_check_edge_lists(g)
  x_assert_graph_consistent(g)
  debug_inspect([ for w in g.node_weights() => w ], content="[0, 3, 2]")
}

// ---------------------------------------------------------------------------
// weight iterators, extend_with_edges, adjacency accessors, into_nodes_edges
// ---------------------------------------------------------------------------

///|
/// port: test_weight_iterators
/// Adapted: MoonBit has no `_mut` iterators, so the mutation half of the Rust
/// test uses `set_node_weight` / `set_edge_weight` driven by `node_ids()` /
/// `edge_ids()`.
test "port: test_weight_iterators" {
  let gr : @graph.Graph[String, Double] = @graph.Graph::new()
  let a = gr.add_node("A")
  let b = gr.add_node("B")
  let c = gr.add_node("C")
  let d = gr.add_node("D")
  let e = gr.add_node("E")
  let f = gr.add_node("F")
  let g = gr.add_node("G")
  let _ = gr.add_edge(a, b, 7.0)
  let _ = gr.add_edge(a, d, 5.0)
  let _ = gr.add_edge(d, b, 9.0)
  let _ = gr.add_edge(b, c, 8.0)
  let _ = gr.add_edge(b, e, 7.0)
  let _ = gr.add_edge(c, e, 5.0)
  let _ = gr.add_edge(d, e, 15.0)
  let _ = gr.add_edge(d, f, 6.0)
  let _ = gr.add_edge(f, e, 8.0)
  let _ = gr.add_edge(f, g, 11.0)
  let _ = gr.add_edge(e, g, 9.0)
  assert_eq(gr.node_weights().count(), gr.node_count())
  assert_eq(gr.edge_weights().count(), gr.edge_count())
  // Add a disjoint part.
  let h = gr.add_node("H")
  let i = gr.add_node("I")
  let j = gr.add_node("J")
  let _ = gr.add_edge(h, i, 1.0)
  let _ = gr.add_edge(h, j, 3.0)
  let _ = gr.add_edge(i, j, 1.0)
  assert_eq(gr.node_weights().count(), gr.node_count())
  assert_eq(gr.edge_weights().count(), gr.edge_count())
  // Weights are yielded in index order.
  debug_inspect(
    [
      for w in gr.node_weights() => w
    ],
    content=(
      #|["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    ),
  )
  let sum = gr.edge_weights().fold(init=0.0, (acc, w) => acc + w)
  assert_eq(sum, 95.0)
  // Overwrite every node weight, then negate every edge weight.
  for n in gr.node_ids() {
    gr.set_node_weight(n, "x")
  }
  for w in gr.node_weights() {
    assert_eq(w, "x")
  }
  let old = [ for w in gr.edge_weights() => w ]
  for eid in gr.edge_ids() {
    gr.set_edge_weight(eid, -gr.edge_weight(eid).unwrap())
  }
  let now = [ for w in gr.edge_weights() => w ]
  for k in 0..<now.length() {
    assert_eq(now[k], -old[k])
  }
}

///|
/// Adapted from petgraph's doc example for `extend_with_edges`.
test "extend_with_edges adds edges and auto-creates nodes" {
  let g : @graph.Graph[Unit, Int] = @graph.Graph::new()
  let a = g.add_node(())
  let b = g.add_node(())
  let c = g.add_node(())
  let d = g.add_node(())
  g.extend_with_edges([(a, b, 7), (a, c, 8), (a, d, 9), (b, c, 10)])
  debug_inspect(g.node_count(), content="4")
  debug_inspect(g.edge_count(), content="4")
  debug_inspect([ for w in g.edge_weights() => w ], content="[7, 8, 9, 10]")
  x_check_edge_lists(g)
  // Nodes are created on demand with the default weight.
  let h : @graph.Graph[Int, Int] = @graph.Graph::new()
  h.extend_with_edges([(x_n(0), x_n(3), 1), (x_n(5), x_n(1), 2)])
  debug_inspect(h.node_count(), content="6")
  debug_inspect(
    [
      for w in h.node_weights() => w
    ],
    content="[0, 0, 0, 0, 0, 0]",
  )
  debug_inspect(h.edge_count(), content="2")
  debug_inspect(
    x_ref_endpoints(h.edge_references()),
    content="[(0, 3), (5, 1)]",
  )
  x_check_edge_lists(h)
  // Extending an existing graph appends, it does not reset.
  h.extend_with_edges([(x_n(0), x_n(1), 3)])
  debug_inspect(h.edge_count(), content="3")
  debug_inspect(h.node_count(), content="6")
  x_check_edge_lists(h)
}

///|
/// `first_edge` / `next_edge` walk the same intrusive lists as
/// `edges_directed`, in the same order.
test "first_edge and next_edge walk the adjacency lists" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(a, c, 1)
  let _ = g.add_edge(b, c, 2)
  // Outgoing list of a: #1 then #0.
  debug_inspect(
    g.first_edge(a, Outgoing).map(e => e.index()),
    content="Some(1)",
  )
  debug_inspect(
    g.next_edge(@graph.EdgeId::new(1), Outgoing).map(e => e.index()),
    content="Some(0)",
  )
  debug_inspect(g.next_edge(@graph.EdgeId::new(0), Outgoing), content="None")
  // Incoming list of c: #2 then #1.
  debug_inspect(
    g.first_edge(c, Incoming).map(e => e.index()),
    content="Some(2)",
  )
  debug_inspect(
    g.next_edge(@graph.EdgeId::new(2), Incoming).map(e => e.index()),
    content="Some(1)",
  )
  // c has no outgoing edge; unknown ids give None.
  debug_inspect(g.first_edge(c, Outgoing), content="None")
  debug_inspect(g.first_edge(@graph.NodeId::new(99), Outgoing), content="None")
  debug_inspect(g.next_edge(@graph.EdgeId::new(99), Outgoing), content="None")
  // Walking manually reproduces `edges_directed`.
  let walked : Array[Int] = []
  let mut cur = g.first_edge(a, Outgoing)
  while cur is Some(e) {
    walked.push(e.index())
    cur = g.next_edge(e, Outgoing)
  }
  debug_inspect(walked, content="[1, 0]")
  debug_inspect(x_edge_indices(g.edges_directed(a, Outgoing)), content="[1, 0]")
}

///|
test "into_nodes_edges decomposes the graph" {
  let g : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = g.add_node("a")
  let b = g.add_node("b")
  let c = g.add_node("c")
  let _ = g.add_edge(a, b, 10)
  let _ = g.add_edge(b, c, 20)
  let _ = g.add_edge(c, a, 30)
  let (nodes, edges) = g.into_nodes_edges()
  debug_inspect(
    nodes,
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    [
      for e in edges => (e.0.index(), e.1.index(), e.2)
    ],
    content="[(0, 1, 10), (1, 2, 20), (2, 0, 30)]",
  )
  // The graph itself is untouched (MoonBit cannot consume `self`).
  debug_inspect(g.node_count(), content="3")
  debug_inspect(g.edge_count(), content="3")
  // Round-trip: rebuilding from the decomposition gives the same graph.
  let g2 : @graph.Graph[String, Int] = @graph.Graph::new()
  for w in nodes {
    let _ = g2.add_node(w)
  }
  for e in edges {
    let _ = g2.add_edge(e.0, e.1, e.2)
  }
  debug_inspect(
    x_ref_endpoints(g2.edge_references()),
    content="[(0, 1), (1, 2), (2, 0)]",
  )
  x_check_edge_lists(g2)
  // Empty graph.
  let e : @graph.Graph[Int, Int] = @graph.Graph::new()
  let (ns, es) = e.into_nodes_edges()
  debug_inspect(ns.length(), content="0")
  debug_inspect(es.length(), content="0")
}
