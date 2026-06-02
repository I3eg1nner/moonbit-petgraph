// Ported from petgraph's crates/petgraph/tests/graph.rs traversal tests.
// The package being tested provides Walker-style traversals over
// `@graph.NeighborSource`; petgraph's `walker.iter(&g).count()` is reproduced
// here by draining `walker.next(g)` into an array and taking its length.
//
// NOTE: petgraph's `Reversed(&gr)` adaptor is NOT implemented in our `@visit`
// package, so the `iter(Reversed(&gr))` assertions in the original `dfs` and
// `bfs` tests are skipped (documented per-test below).

///|
/// Count how many nodes a `Dfs` walker yields from its current state.
fn count_dfs(dfs : @visit.Dfs, g : @graph.Graph[String, Double]) -> Int {
  let mut n = 0
  while dfs.next(g) is Some(_) {
    n = n + 1
  }
  n
}

///|
/// Count how many nodes a `Bfs` walker yields from its current state.
fn count_bfs(bfs : @visit.Bfs, g : @graph.Graph[String, Double]) -> Int {
  let mut n = 0
  while bfs.next(g) is Some(_) {
    n = n + 1
  }
  n
}

///|
/// Ported from `dfs` in tests/graph.rs.
///
/// Builds the H/I/J/K graph (Z disconnected) and checks reachable-node counts
/// from various start nodes. The two `Reversed(&gr)` assertions are skipped
/// because we do not implement the `Reversed` adaptor.
test "dfs (ported: dfs)" {
  let gr : @graph.Graph[String, Double] = @graph.Graph::new()
  let h = gr.add_node("H")
  let i = gr.add_node("I")
  let j = gr.add_node("J")
  let k = gr.add_node("K")
  // Z is disconnected.
  let _z = gr.add_node("Z")
  gr.add_edge(h, i, 1.0) |> ignore
  gr.add_edge(h, j, 3.0) |> ignore
  gr.add_edge(i, j, 1.0) |> ignore
  gr.add_edge(i, k, 2.0) |> ignore

  // From H, all of H, I, J, K are reachable (Z is not).
  assert_eq(count_dfs(@visit.Dfs::new(gr, h), gr), 4)
  // Skipped: Dfs::new(&gr, h).iter(Reversed(&gr)).count() == 1 (no Reversed).
  // Skipped: Dfs::new(&gr, k).iter(Reversed(&gr)).count() == 3 (no Reversed).
  // From I, reachable: I, J, K.
  assert_eq(count_dfs(@visit.Dfs::new(gr, i), gr), 3)
}

///|
/// Ported from `dfs_order` in tests/graph.rs.
///
///       H
///     / | \
///    I  J  K
///     \___/
///
/// J cannot be visited between I and K in a depth-first search from H.
test "dfs_order (ported: dfs_order)" {
  let gr : @graph.Graph[String, Unit] = @graph.Graph::new()
  let h = gr.add_node("H")
  let i = gr.add_node("I")
  let j = gr.add_node("J")
  let k = gr.add_node("K")
  gr.add_edge(h, i, ()) |> ignore
  gr.add_edge(h, j, ()) |> ignore
  gr.add_edge(h, k, ()) |> ignore
  gr.add_edge(i, k, ()) |> ignore
  gr.add_edge(k, i, ()) |> ignore
  let mut seen_i = false
  let mut seen_k = false
  let dfs = @visit.Dfs::new(gr, h)
  while dfs.next(gr) is Some(node) {
    seen_i = seen_i || node == i
    seen_k = seen_k || node == k
    // J must not appear when exactly one of I/K has been seen (xor).
    assert_eq(node == j && seen_i != seen_k, false)
  }
}

///|
/// Ported from `bfs` in tests/graph.rs.
///
/// Checks reachable-node counts and the explicit next() sequence from H.
/// The two `Reversed(&gr)` assertions are skipped (no Reversed adaptor).
test "bfs (ported: bfs)" {
  let gr : @graph.Graph[String, Double] = @graph.Graph::new()
  let h = gr.add_node("H")
  let i = gr.add_node("I")
  let j = gr.add_node("J")
  let k = gr.add_node("K")
  // Z is disconnected.
  let _z = gr.add_node("Z")
  gr.add_edge(h, i, 1.0) |> ignore
  gr.add_edge(h, j, 3.0) |> ignore
  gr.add_edge(i, j, 1.0) |> ignore
  gr.add_edge(i, k, 2.0) |> ignore
  assert_eq(count_bfs(@visit.Bfs::new(gr, h), gr), 4)
  // Skipped: Bfs::new(&gr, h).iter(Reversed(&gr)).count() == 1 (no Reversed).
  // Skipped: Bfs::new(&gr, k).iter(Reversed(&gr)).count() == 3 (no Reversed).
  assert_eq(count_bfs(@visit.Bfs::new(gr, i), gr), 3)

  // Explicit BFS step sequence from H.
  // (Compare on raw booleans to avoid the deprecated Show-on-Option path.)
  let bfs = @visit.Bfs::new(gr, h)
  assert_eq(bfs.next(gr) is Some(n) && n == h, true)
  let nx1 = bfs.next(gr)
  assert_eq(nx1 is Some(n) && (n == i || n == j), true)
  let nx2 = bfs.next(gr)
  assert_eq(nx2 is Some(n) && (n == i || n == j), true)
  assert_eq(nx1 != nx2, true)
  assert_eq(bfs.next(gr) is Some(n) && n == k, true)
  assert_eq(bfs.next(gr) is None, true)
}

///|
/// Ported from `usize_index` in tests/graph.rs.
///
/// Walks a 2-node graph with `Dfs` and mutates node weights along the way,
/// checking that exactly the reachable nodes were visited. (The original also
/// asserts an edge weight; that is unrelated to traversal and omitted.)
test "usize_index (ported: usize_index, traversal portion)" {
  let gr : @graph.Graph[Int, Double] = @graph.Graph::new()
  let a = gr.add_node(0)
  let b = gr.add_node(1)
  gr.add_edge(a, b, 1.2) |> ignore
  let visited = []
  let dfs = @visit.Dfs::new(gr, a)
  while dfs.next(gr) is Some(nx) {
    visited.push(nx.index())
  }
  // Both nodes reachable from a, in DFS preorder a then b.
  json_inspect(visited, content=[0, 1])
}

///|
/// Check that `order` is a valid topological order of `gr`: every node appears,
/// and for each edge a->b, a precedes b. Ported from `assert_is_topo_order`.
fn assert_is_topo_order(
  gr : @graph.Graph[String, Double],
  edges : Array[(Int, Int)],
  order : Array[Int],
) -> Unit raise {
  assert_eq(order.length(), gr.node_count())
  fn pos(x : Int) -> Int {
    let mut found = -1
    for idx, v in order {
      if v == x {
        found = idx
        break
      }
    }
    found
  }

  for e in edges {
    let (a, b) = e
    let ai = pos(a)
    let bi = pos(b)
    assert_eq(ai >= 0 && bi >= 0, true)
    // a must come strictly before b.
    assert_eq(ai < bi, true)
  }
}

///|
/// Ported from `test_toposort` in tests/graph.rs.
///
/// petgraph uses `algo::toposort`; that lives in our `@algo` package (out of
/// scope here), so we drive the in-scope `@visit.Topo` walker directly to
/// produce the order and verify the topological-order property. For a DAG,
/// `Topo` yields every node exactly once.
test "test_toposort (ported: test_toposort)" {
  let gr : @graph.Graph[String, Double] = @graph.Graph::new()
  let a = gr.add_node("A")
  let b = gr.add_node("B")
  let c = gr.add_node("C")
  let d = gr.add_node("D")
  let e = gr.add_node("E")
  let f = gr.add_node("F")
  let g = gr.add_node("G")
  let edges : Array[(Int, Int)] = [
    (a.index(), b.index()),
    (a.index(), d.index()),
    (d.index(), b.index()),
    (b.index(), c.index()),
    (b.index(), e.index()),
    (c.index(), e.index()),
    (d.index(), e.index()),
    (d.index(), f.index()),
    (f.index(), e.index()),
    (f.index(), g.index()),
    (e.index(), g.index()),
  ]
  for ed in edges {
    let (s, t) = ed
    gr.add_edge(@graph.NodeId::new(s), @graph.NodeId::new(t), 0.0) |> ignore
  }
  // add a disjoint part
  let h = gr.add_node("H")
  let i = gr.add_node("I")
  let jj = gr.add_node("J")
  gr.add_edge(h, i, 1.0) |> ignore
  gr.add_edge(h, jj, 3.0) |> ignore
  gr.add_edge(i, jj, 1.0) |> ignore
  edges.push((h.index(), i.index()))
  edges.push((h.index(), jj.index()))
  edges.push((i.index(), jj.index()))
  let topo = @visit.Topo::new(gr)
  let order = []
  while topo.next(gr) is Some(n) {
    order.push(n.index())
  }
  assert_eq(order.length(), gr.node_count())
  assert_is_topo_order(gr, edges, order)
}

///|
/// Ported from `test_toposort_eq` in tests/graph.rs.
///
/// A->B should topologically sort to exactly [A, B]. Uses the `@visit.Topo`
/// walker in place of `algo::toposort` (see note on `test_toposort`).
test "test_toposort_eq (ported: test_toposort_eq)" {
  let g : @graph.Graph[String, Unit] = @graph.Graph::new()
  let a = g.add_node("A")
  let b = g.add_node("B")
  g.add_edge(a, b, ()) |> ignore
  let topo = @visit.Topo::new(g)
  let order = []
  while topo.next(g) is Some(n) {
    order.push(n.index())
  }
  json_inspect(order, content=[0, 1])
}
