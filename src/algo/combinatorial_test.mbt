// Tests for the combinatorial algorithms: maximal_cliques, greedy_matching /
// maximum_matching, dsatur_coloring, all_simple_paths /
// all_simple_paths_multi and greedy_feedback_arc_set.
//
// Test names prefixed with `port:` are adapted from the corresponding upstream
// petgraph tests (crates/petgraph/tests/{matching,maximal_cliques,coloring}.rs
// and the `mod test` inside crates/petgraph/src/algo/simple_paths.rs), keeping
// the original Rust test names.

///|
/// Shorthand for `@graph.NodeId::new`.
fn nid(i : Int) -> @graph.NodeId {
  @graph.NodeId::new(i)
}

///|
/// Lexicographic comparison of two index lists. `Array`'s derived ordering
/// compares lengths first, which would scramble the canonical orders below.
fn lex_compare(a : Array[Int], b : Array[Int]) -> Int {
  let m = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<m {
    if a[i] != b[i] {
      return a[i].compare(b[i])
    }
  }
  a.length().compare(b.length())
}

///|
/// Render a list of node lists canonically: each inner list sorted, then the
/// outer list sorted lexicographically. Used to compare set-valued results
/// (cliques) independently of the traversal order.
fn canon_node_lists(lists : Array[Array[@graph.NodeId]]) -> Array[Array[Int]] {
  let out = [ for l in lists => [ for n in l => n.index() ] ]
  for l in out {
    l.sort()
  }
  out.sort_by(lex_compare)
  out
}

///|
/// Collect the paths of an iterator as index arrays, sorted lexicographically
/// (the outer order only; each path keeps its own order, which is meaningful).
fn canon_paths(paths : Iter[Array[@graph.NodeId]]) -> Array[Array[Int]] {
  let out = [ for p in paths => [ for n in p => n.index() ] ]
  out.sort_by(lex_compare)
  out
}

///|
/// The matched edges of a `Matching` as sorted `(lo, hi)` index pairs.
fn[N, E] matching_edges(m : @algo.Matching[N, E]) -> Array[(Int, Int)] {
  let out = [ for e in m.edges() => (e.0.index(), e.1.index()) ]
  out.sort()
  out
}

///|
/// The matched nodes of a `Matching` as sorted indices.
fn[N, E] matching_nodes(m : @algo.Matching[N, E]) -> Array[Int] {
  let out = [ for n in m.nodes() => n.index() ]
  out.sort()
  out
}

///|
/// Check that `m` really is a matching of `g`: every reported edge exists in
/// the graph, `mate` is symmetric, and no node is matched twice.
fn[N, E] assert_valid_matching(
  g : @graph.Graph[N, E],
  m : @algo.Matching[N, E],
) -> Unit raise {
  let mut count = 0
  for e in m.edges() {
    let (a, b) = e
    assert_true(g.find_edge(a, b) is Some(_) || g.find_edge(b, a) is Some(_))
    assert_eq(m.mate(a), Some(b))
    assert_eq(m.mate(b), Some(a))
    count = count + 1
  }
  assert_eq(count, m.len())
  // `mate` is an involution without fixed points.
  for n in m.nodes() {
    guard m.mate(n) is Some(partner) else { fail("matched node without mate") }
    assert_true(partner != n)
    assert_eq(m.mate(partner), Some(n))
  }
}

// ---------------------------------------------------------------------------
// maximal_cliques
// ---------------------------------------------------------------------------

///|
test "port: test_maximal_cliques_empty_graph" {
  // As in petgraph, an empty graph yields exactly one (empty) clique.
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new()
  let cliques = @algo.maximal_cliques(g)
  json_inspect(canon_node_lists(cliques), content=[[]])
}

///|
test "port: test_maximal_cliques_undirected_sparse_graph" {
  // c     d
  //
  // b --- a
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let _c = g.add_node(2)
  let _d = g.add_node(3)
  g.add_edge(a, b, ()) |> ignore
  g.add_edge(b, a, ()) |> ignore
  let cliques = @algo.maximal_cliques(g)
  inspect(cliques.length(), content="3")
  json_inspect(canon_node_lists(cliques), content=[[0, 1], [2], [3]])
}

///|
test "port: test_maximal_cliques_directed_sparse_graph" {
  // c     d
  //
  // b <-> a
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let _c = g.add_node(2)
  let _d = g.add_node(3)
  g.add_edge(a, b, ()) |> ignore
  g.add_edge(b, a, ()) |> ignore
  let cliques = @algo.maximal_cliques(g)
  inspect(cliques.length(), content="3")
  json_inspect(canon_node_lists(cliques), content=[[0, 1], [2], [3]])
}

///|
test "port: test_maximal_cliques_undirected" {
  // f - d - e - a
  //     |   | /
  //     c - b
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g = @graph.from_edges_undirected([
    (0, 1),
    (0, 4),
    (1, 4),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 5),
  ])
  let cliques = @algo.maximal_cliques(g)
  inspect(cliques.length(), content="5")
  json_inspect(canon_node_lists(cliques), content=[
    [0, 1, 4],
    [1, 2],
    [2, 3],
    [3, 4],
    [4, 5],
  ])
}

///|
test "port: test_maximal_cliques_directed" {
  // f <-> d <-> e <-> a
  //       ^     ^     ^
  //       |     |     |
  //       v     v     |
  //       c <-> b <---|
  // a=0 b=1 c=2 d=3 e=4 f=5, every edge present in both directions.
  let base = [(0, 1), (0, 4), (1, 4), (1, 2), (2, 3), (3, 4), (3, 5)]
  let sym : Array[(Int, Int)] = []
  for e in base {
    sym.push(e)
    sym.push((e.1, e.0))
  }
  let g = @graph.from_edges(sym)
  let cliques = @algo.maximal_cliques(g)
  inspect(cliques.length(), content="5")
  json_inspect(canon_node_lists(cliques), content=[
    [0, 1, 4],
    [1, 2],
    [2, 3],
    [3, 4],
    [3, 5],
  ])
}

///|
test "maximal_cliques on a complete graph is the whole vertex set" {
  // K4: the single maximal clique is {0,1,2,3}.
  let g = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
  ])
  json_inspect(canon_node_lists(@algo.maximal_cliques(g)), content=[
    [0, 1, 2, 3],
  ])
  // A 4-cycle without chords has four maximal cliques, one per edge.
  let c4 = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (3, 0)])
  json_inspect(canon_node_lists(@algo.maximal_cliques(c4)), content=[
    [0, 1],
    [0, 3],
    [1, 2],
    [2, 3],
  ])
}

// ---------------------------------------------------------------------------
// matching
// ---------------------------------------------------------------------------

///|
test "port: greedy_empty" {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  let m = @algo.greedy_matching(g)
  json_inspect(matching_edges(m), content=[])
  json_inspect(matching_nodes(m), content=[])
  inspect(m.is_empty(), content="true")
}

///|
test "port: greedy_disjoint" {
  let g = @graph.from_edges_undirected([(0, 1), (2, 3)])
  let m = @algo.greedy_matching(g)
  json_inspect(matching_edges(m), content=[[0, 1], [2, 3]])
  json_inspect(matching_nodes(m), content=[0, 1, 2, 3])
  assert_valid_matching(g, m)
}

///|
test "port: greedy_odd_path" {
  // The greedy heuristic may produce {(0,1),(2,3)} or just {(1,2)}.
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  let m = @algo.greedy_matching(g)
  let edges = matching_edges(m)
  assert_true(edges == [(0, 1), (2, 3)] || edges == [(1, 2)])
  let nodes = matching_nodes(m)
  assert_true(nodes == [0, 1, 2, 3] || nodes == [1, 2])
  assert_valid_matching(g, m)
}

///|
test "port: greedy_star" {
  // A star can only ever match the center with one leaf.
  let g = @graph.from_edges_undirected([(0, 1), (0, 2), (0, 3)])
  let m = @algo.greedy_matching(g)
  let edges = matching_edges(m)
  assert_true(edges == [(0, 1)] || edges == [(0, 2)] || edges == [(0, 3)])
  inspect(m.len(), content="1")
  assert_valid_matching(g, m)
}

///|
test "port: maximum_empty" {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  let m = @algo.maximum_matching(g)
  json_inspect(matching_edges(m), content=[])
  json_inspect(matching_nodes(m), content=[])
  // An empty graph has an even node count and 0 == 0/2 edges.
  inspect(m.is_perfect(), content="true")
}

///|
test "port: maximum_disjoint" {
  let g = @graph.from_edges_undirected([(0, 1), (2, 3)])
  let m = @algo.maximum_matching(g)
  json_inspect(matching_edges(m), content=[[0, 1], [2, 3]])
  json_inspect(matching_nodes(m), content=[0, 1, 2, 3])
  inspect(m.is_perfect(), content="true")
  assert_valid_matching(g, m)
}

///|
test "port: maximum_odd_path" {
  // Unlike greedy, the maximum matching of a 4-node path is always perfect.
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  let m = @algo.maximum_matching(g)
  json_inspect(matching_edges(m), content=[[0, 1], [2, 3]])
  json_inspect(matching_nodes(m), content=[0, 1, 2, 3])
  inspect(m.is_perfect(), content="true")
  assert_valid_matching(g, m)
}

///|
test "maximum_matching doc example (blossom on a-b-c triangle)" {
  //    +-- b ---- d ---- f
  //   /    |      |
  //  a     |      |
  //   \    |      |
  //    +-- c ---- e
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (1, 2),
    (1, 3),
    (2, 4),
    (3, 4),
    (3, 5),
  ])
  let m = @algo.maximum_matching(g)
  inspect(m.len(), content="3")
  inspect(m.is_perfect(), content="true")
  assert_valid_matching(g, m)
  json_inspect(matching_edges(m), content=[[0, 1], [2, 4], [3, 5]])
  inspect(m.contains_edge(nid(0), nid(1)), content="true")
  inspect(m.contains_edge(nid(2), nid(4)), content="true")
  debug_inspect(m.mate(nid(3)), content="Some(NodeId(5))")
  debug_inspect(m.mate(nid(5)), content="Some(NodeId(3))")
}

///|
test "maximum_matching on an odd cycle needs blossom contraction" {
  // C5 has maximum matching size 2 (no perfect matching on 5 vertices).
  let c5 = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)])
  let m5 = @algo.maximum_matching(c5)
  inspect(m5.len(), content="2")
  inspect(m5.is_perfect(), content="false")
  assert_valid_matching(c5, m5)

  // C5 plus a pendant vertex 5 attached to 0 has a perfect matching of size 3;
  // finding it requires contracting the odd cycle.
  let c5p = @graph.from_edges_undirected([
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 0),
    (0, 5),
  ])
  let m6 = @algo.maximum_matching(c5p)
  inspect(m6.len(), content="3")
  inspect(m6.is_perfect(), content="true")
  assert_valid_matching(c5p, m6)
}

///|
test "maximum_matching on the Petersen graph is perfect" {
  // The Petersen graph (10 vertices, 15 edges) is 3-regular and bridgeless, so
  // by Petersen's theorem it has a perfect matching of size 5. It also contains
  // many odd cycles, exercising the blossom machinery.
  let g = @graph.from_edges_undirected([
    // outer 5-cycle
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 0),
    // spokes
    (0, 5),
    (1, 6),
    (2, 7),
    (3, 8),
    (4, 9),
    // inner pentagram
    (5, 7),
    (7, 9),
    (9, 6),
    (6, 8),
    (8, 5),
  ])
  let m = @algo.maximum_matching(g)
  inspect(m.len(), content="5")
  inspect(m.is_perfect(), content="true")
  assert_valid_matching(g, m)
}

///|
test "maximum_matching beats greedy where greedy gets stuck" {
  // A path of 6 nodes: the maximum matching has 3 edges. Greedy may find fewer,
  // but maximum_matching must always reach 3 and be perfect.
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)])
  let greedy = @algo.greedy_matching(g)
  let maximum = @algo.maximum_matching(g)
  assert_true(greedy.len() <= maximum.len())
  inspect(maximum.len(), content="3")
  inspect(maximum.is_perfect(), content="true")
  assert_valid_matching(g, maximum)
  // A star plus a disjoint edge: maximum matching is 2.
  let g2 = @graph.from_edges_undirected([(0, 1), (0, 2), (0, 3), (4, 5)])
  let m2 = @algo.maximum_matching(g2)
  inspect(m2.len(), content="2")
  assert_valid_matching(g2, m2)
}

///|
test "maximum_matching ignores self-loops and handles isolated nodes" {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  for _i in 0..<5 {
    g.add_node(g.node_count()) |> ignore
  }
  g.add_edge(nid(0), nid(0), ()) |> ignore // self-loop: never matchable
  g.add_edge(nid(1), nid(2), ()) |> ignore
  g.add_edge(nid(2), nid(3), ()) |> ignore
  let m = @algo.maximum_matching(g)
  inspect(m.len(), content="1")
  inspect(m.contains_node(nid(0)), content="false")
  inspect(m.contains_node(nid(4)), content="false")
  inspect(m.is_perfect(), content="false")
  assert_valid_matching(g, m)
}

// ---------------------------------------------------------------------------
// dsatur_coloring
// ---------------------------------------------------------------------------

///|
/// Assert that `coloring` is a proper coloring of `g` (adjacent nodes differ)
/// and that every color is `< nb_colors`.
fn[N, E] assert_proper_coloring(
  g : @graph.Graph[N, E],
  coloring : Map[@graph.NodeId, Int],
  nb_colors : Int,
) -> Unit raise {
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((a, b)) else { fail("dangling edge") }
    if a == b {
      continue
    }
    guard coloring.get(a) is Some(ca) && coloring.get(b) is Some(cb) else {
      fail("uncolored node")
    }
    assert_true(ca != cb)
    assert_true(ca < nb_colors && cb < nb_colors)
  }
}

///|
test "port: dsatur_coloring_cycle6" {
  // Node insertion order in the upstream test is a, d, b, c, e, f, so:
  // a=0 d=1 b=2 c=3 e=4 f=5.
  let g = @graph.from_edges_undirected([
    (0, 2), // a-b
    (2, 3), // b-c
    (3, 1), // c-d
    (1, 4), // d-e
    (4, 5), // e-f
    (5, 4), // f-e (parallel edge, as upstream)
  ])
  let (coloring, nb_colors) = @algo.dsatur_coloring(g)
  inspect(nb_colors, content="2")
  inspect(coloring.length(), content="6")
  assert_proper_coloring(g, coloring, nb_colors)
}

///|
test "port: dsatur_coloring_bipartite" {
  // a=0 d=1 b=2 c=3 e=4 f=5 g=6 h=7 i=8 j=9 k=10 l=11
  let g = @graph.from_edges_undirected([
    (0, 2), // a-b
    (0, 6), // a-g
    (0, 11), // a-l
    (2, 1), // b-d
    (2, 7), // b-h
    (2, 10), // b-k
    (3, 1), // c-d
    (3, 10), // c-k
    (1, 11), // d-l
    (4, 5), // e-f
    (4, 9), // e-j
    (5, 8), // f-i
    (5, 11), // f-l
    (6, 7), // g-h
    (6, 9), // g-j
    (6, 10), // g-k
    (7, 8), // h-i
    (8, 9), // i-j
    (8, 10), // i-k
  ])
  let (coloring, nb_colors) = @algo.dsatur_coloring(g)
  inspect(nb_colors, content="2")
  inspect(coloring.length(), content="12")
  assert_proper_coloring(g, coloring, nb_colors)
}

///|
test "dsatur_coloring on complete graphs and disconnected graphs" {
  // K4 needs exactly 4 colors.
  let k4 = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
  ])
  let (c4, n4) = @algo.dsatur_coloring(k4)
  inspect(n4, content="4")
  assert_proper_coloring(k4, c4, n4)
  // Three isolated nodes need one color; petgraph reports max_color + 1.
  let iso : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  for _i in 0..<3 {
    iso.add_node(iso.node_count()) |> ignore
  }
  let (ci, ni) = @algo.dsatur_coloring(iso)
  inspect(ni, content="1")
  inspect(ci.length(), content="3")
  // An empty graph reports 1 color (the `max_color + 1` edge case).
  let empty : @graph.Graph[Int, Unit] = @graph.Graph::new_undirected()
  let (ce, ne) = @algo.dsatur_coloring(empty)
  inspect(ne, content="1")
  inspect(ce.length(), content="0")
}

// ---------------------------------------------------------------------------
// simple_paths
// ---------------------------------------------------------------------------

///|
test "port: test_all_simple_paths" {
  let g = @graph.from_edges([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
    (2, 4),
    (3, 2),
    (3, 4),
    (4, 2),
    (4, 5),
    (5, 2),
    (5, 3),
  ])
  let paths = canon_paths(@algo.all_simple_paths(g, nid(0), nid(5), 0))
  inspect(paths.length(), content="8")
  json_inspect(paths, content=[
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 4, 5],
    [0, 1, 3, 2, 4, 5],
    [0, 1, 3, 4, 5],
    [0, 2, 3, 4, 5],
    [0, 2, 4, 5],
    [0, 3, 2, 4, 5],
    [0, 3, 4, 5],
  ])
}

///|
test "port: test_one_simple_path" {
  let g = @graph.from_edges([(0, 1), (2, 1)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(1), 0)), content=[
    [0, 1],
  ])
}

///|
test "port: test_no_simple_paths" {
  let g = @graph.from_edges([(0, 1), (2, 1)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(2), 0)), content=[])
}

///|
test "port: test_path_graph" {
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(3), 0)), content=[
    [0, 1, 2, 3],
  ])
}

///|
test "port: test_all_simple_paths_ignores_cycle" {
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 0), (1, 3)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(3), 0)), content=[
    [0, 1, 3],
  ])
}

///|
test "port: test_simple_path_source_target" {
  // A path from a node to itself is never simple.
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(1), nid(1), 0)), content=[])
}

///|
test "port: test_simple_paths_cutoff" {
  let g = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
  ])
  json_inspect(
    canon_paths(
      @algo.all_simple_paths(g, nid(0), nid(1), 0, max_intermediate_nodes=0),
    ),
    content=[[0, 1]],
  )
  json_inspect(
    canon_paths(
      @algo.all_simple_paths(g, nid(0), nid(1), 0, max_intermediate_nodes=1),
    ),
    content=[[0, 1], [0, 2, 1], [0, 3, 1]],
  )
}

///|
test "port: test_all_simple_paths_empty" {
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  json_inspect(
    canon_paths(
      @algo.all_simple_paths(g, nid(0), nid(3), 0, max_intermediate_nodes=1),
    ),
    content=[],
  )
}

///|
test "port: test_all_simple_paths_directed" {
  let g = @graph.from_edges([(1, 2), (2, 3), (3, 2), (2, 1)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(1), nid(3), 0)), content=[
    [1, 2, 3],
  ])
}

///|
test "port: test_all_simple_paths_corner_cases" {
  let g : @graph.Graph[Int, Unit] = @graph.Graph::new()
  g.add_node(0) |> ignore
  g.add_node(1) |> ignore
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(0), 0)), content=[])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(1), 0)), content=[])
}

///|
test "port: test_simple_paths_min_intermediate_nodes" {
  let g = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
  ])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(1), 2)), content=[
    [0, 2, 3, 1],
    [0, 3, 2, 1],
  ])
}

///|
test "port: test_simple_paths_from_node_to_itself_in_complete_graph" {
  // The only simple path from a node to itself would be the node alone.
  let g = @graph.from_edges([(0, 1), (0, 2), (1, 0), (1, 2), (2, 0), (2, 1)])
  json_inspect(canon_paths(@algo.all_simple_paths(g, nid(0), nid(0), 0)), content=[])
}

///|
test "port: test_multi_target_paths" {
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (2, 4)])
  json_inspect(
    canon_paths(@algo.all_simple_paths_multi(g, nid(0), [nid(3), nid(4)], 0)),
    content=[[0, 1, 2, 3], [0, 1, 2, 4]],
  )
}

///|
test "port: test_digraph_multi_target_paths" {
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 3), (2, 4)])
  json_inspect(
    canon_paths(@algo.all_simple_paths_multi(g, nid(0), [nid(3), nid(4)], 0)),
    content=[[0, 1, 2, 3], [0, 1, 2, 4]],
  )
}

///|
test "port: test_multi_target_paths_cutoff" {
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (2, 4)])
  json_inspect(
    canon_paths(
      @algo.all_simple_paths_multi(
        g,
        nid(0),
        [nid(3), nid(4)],
        0,
        max_intermediate_nodes=2,
      ),
    ),
    content=[[0, 1, 2, 3], [0, 1, 2, 4]],
  )
}

///|
test "port: test_digraph_multi_target_paths_cutoff" {
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 3), (2, 4)])
  json_inspect(
    canon_paths(
      @algo.all_simple_paths_multi(
        g,
        nid(0),
        [nid(3), nid(4)],
        0,
        max_intermediate_nodes=2,
      ),
    ),
    content=[[0, 1, 2, 3], [0, 1, 2, 4]],
  )
}

///|
test "port: test_multi_target_paths_inline" {
  // Target 2 lies on the way to target 3, so both prefixes are reported.
  let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  json_inspect(
    canon_paths(@algo.all_simple_paths_multi(g, nid(0), [nid(2), nid(3)], 0)),
    content=[[0, 1, 2], [0, 1, 2, 3]],
  )
}

///|
test "port: test_multi_target_paths_in_cycle" {
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 0), (1, 3)])
  json_inspect(
    canon_paths(@algo.all_simple_paths_multi(g, nid(0), [nid(2), nid(3)], 0)),
    content=[[0, 1, 2], [0, 1, 3]],
  )
}

///|
test "port: test_multi_target_source_is_target" {
  // The source itself is in the target set but is never reported: a path must
  // have at least two nodes.
  let g = @graph.from_edges_undirected([(0, 1), (1, 2)])
  json_inspect(
    canon_paths(
      @algo.all_simple_paths_multi(g, nid(0), [nid(0), nid(1), nid(2)], 0),
    ),
    content=[[0, 1], [0, 1, 2]],
  )
}

///|
test "port: test_all_simple_paths_on_non_trivial_graph" {
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (1, 5),
    (1, 3),
    (5, 4),
    (4, 2),
    (4, 3),
  ])
  json_inspect(
    canon_paths(@algo.all_simple_paths_multi(g, nid(1), [nid(2), nid(3)], 0)),
    content=[
      [1, 2],
      [1, 2, 3],
      [1, 3],
      [1, 3, 4, 2],
      [1, 5, 4, 2],
      [1, 5, 4, 2, 3],
      [1, 5, 4, 3],
    ],
  )
}

///|
test "port: test_multi_target_paths_min_intermediate_nodes" {
  let g = @graph.from_edges_undirected([
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
  ])
  json_inspect(
    canon_paths(@algo.all_simple_paths_multi(g, nid(0), [nid(1), nid(3)], 2)),
    content=[[0, 1, 2, 3], [0, 2, 1, 3], [0, 2, 3, 1], [0, 3, 2, 1]],
  )
}

///|
test "all_simple_paths is lazy: only the requested prefix is produced" {
  // Same graph as the petgraph doc example: 4 paths in total, but taking 2
  // must not force the rest.
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 3), (0, 1), (1, 3)])
  let all = @algo.all_simple_paths(g, nid(0), nid(3), 0).collect()
  inspect(all.length(), content="4")
  let two = @algo.all_simple_paths(g, nid(0), nid(3), 0).take(2).collect()
  inspect(two.length(), content="2")
}

// ---------------------------------------------------------------------------
// feedback_arc_set
// ---------------------------------------------------------------------------

///|
/// Rebuild `g` without the edges in `fas` and assert the result is acyclic.
/// (Rebuilding rather than calling `remove_edge` avoids the swap-remove index
/// invalidation.)
fn[N, E] assert_fas_breaks_cycles(
  g : @graph.Graph[N, E],
  fas : Array[@graph.EdgeId],
) -> Unit raise {
  let removed : Map[Int, Unit] = Map([])
  for e in fas {
    removed[e.index()] = ()
  }
  let kept : Array[(Int, Int)] = []
  for e in g.edge_ids() {
    if removed.contains(e.index()) {
      continue
    }
    guard g.edge_endpoints(e) is Some((s, t)) else { fail("dangling edge") }
    kept.push((s.index(), t.index()))
  }
  assert_eq(@algo.is_cyclic_directed(@graph.from_edges(kept)), false)
}

///|
test "greedy_feedback_arc_set makes the doc-example graph acyclic" {
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 5),
    (5, 0),
    (4, 1),
    (1, 3),
  ])
  inspect(@algo.is_cyclic_directed(g), content="true")
  let fas = @algo.greedy_feedback_arc_set(g)
  // The heuristic finds a small set here.
  inspect(fas.length(), content="1")
  assert_fas_breaks_cycles(g, fas)
}

///|
test "greedy_feedback_arc_set returns nothing for a DAG" {
  let dag = @graph.from_edges([(0, 1), (0, 2), (1, 3), (2, 3), (3, 4)])
  inspect(@algo.is_cyclic_directed(dag), content="false")
  json_inspect([ for e in @algo.greedy_feedback_arc_set(dag) => e.index() ], content=[])
}

///|
test "greedy_feedback_arc_set always includes self-loops" {
  let g = @graph.from_edges([(0, 0), (0, 1), (1, 2)])
  let fas = @algo.greedy_feedback_arc_set(g)
  json_inspect([ for e in fas => e.index() ], content=[0])
  assert_fas_breaks_cycles(g, fas)
}

///|
test "greedy_feedback_arc_set breaks cycles in several graphs" {
  let graphs = [
    // simple 3-cycle
    @graph.from_edges([(0, 1), (1, 2), (2, 0)]),
    // two nested cycles sharing a node
    @graph.from_edges([(0, 1), (1, 2), (2, 0), (2, 3), (3, 4), (4, 2)]),
    // complete digraph on 4 nodes (every pair, both directions)
    @graph.from_edges([
      (0, 1),
      (1, 0),
      (0, 2),
      (2, 0),
      (0, 3),
      (3, 0),
      (1, 2),
      (2, 1),
      (1, 3),
      (3, 1),
      (2, 3),
      (3, 2),
    ]),
    // a long cycle with chords
    @graph.from_edges([
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 5),
      (5, 6),
      (6, 0),
      (3, 0),
      (5, 2),
      (6, 4),
    ]),
    // disconnected: a DAG component plus a cyclic one
    @graph.from_edges([(0, 1), (1, 2), (3, 4), (4, 5), (5, 3)]),
  ]
  let sizes : Array[Int] = []
  for g in graphs {
    let fas = @algo.greedy_feedback_arc_set(g)
    assert_fas_breaks_cycles(g, fas)
    // The heuristic never reports more than half of the edges plus loops.
    assert_true(fas.length() < g.edge_count())
    sizes.push(fas.length())
  }
  json_inspect(sizes, content=[1, 2, 6, 2, 1])
}

// ---------------------------------------------------------------------------
// maximum_matching against an exact oracle
// ---------------------------------------------------------------------------

///|
/// Exhaustive maximum matching by branching on the lowest-index free node:
/// either leave it unmatched or pair it with each free neighbor. Exponential,
/// but exact — used as an oracle for `maximum_matching`.
fn brute_force_from(
  start : Int,
  n : Int,
  used : Array[Bool],
  adj : Array[Array[Int]],
) -> Int {
  let mut u = start
  while u < n && used[u] {
    u = u + 1
  }
  if u >= n {
    return 0
  }
  used[u] = true
  // Option 1: leave `u` unmatched.
  let mut best = brute_force_from(u + 1, n, used, adj)
  // Option 2: match `u` with any free neighbor.
  for v in adj[u] {
    if !used[v] {
      used[v] = true
      let candidate = 1 + brute_force_from(u + 1, n, used, adj)
      used[v] = false
      if candidate > best {
        best = candidate
      }
    }
  }
  used[u] = false
  best
}

///|
/// The exact size of a maximum matching of `g`, treating it as undirected and
/// ignoring self-loops.
fn[N, E] brute_force_max_matching(g : @graph.Graph[N, E]) -> Int {
  let n = g.node_count()
  let adj : Array[Array[Int]] = Array::makei(n, _ => [])
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((a, b)) else { continue }
    if a != b {
      adj[a.index()].push(b.index())
      adj[b.index()].push(a.index())
    }
  }
  brute_force_from(0, n, Array::make(n, false), adj)
}

///|
test "maximum_matching equals a brute-force oracle on tricky small graphs" {
  let graphs = [
    // triangle with a tail: needs blossom handling
    @graph.from_edges_undirected([(0, 1), (1, 2), (2, 0), (0, 3)]),
    // two triangles joined by a bridge
    @graph.from_edges_undirected([
      (0, 1),
      (1, 2),
      (2, 0),
      (3, 4),
      (4, 5),
      (5, 3),
      (2, 3),
    ]),
    // C7 (odd cycle, no perfect matching)
    @graph.from_edges_undirected([
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 5),
      (5, 6),
      (6, 0),
    ]),
    // "flower": a 5-cycle with a pendant on every vertex
    @graph.from_edges_undirected([
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 0),
      (0, 5),
      (1, 6),
      (2, 7),
      (3, 8),
      (4, 9),
    ]),
    // K5 (odd complete graph)
    @graph.from_edges_undirected([
      (0, 1),
      (0, 2),
      (0, 3),
      (0, 4),
      (1, 2),
      (1, 3),
      (1, 4),
      (2, 3),
      (2, 4),
      (3, 4),
    ]),
    // complete bipartite K3,3
    @graph.from_edges_undirected([
      (0, 3),
      (0, 4),
      (0, 5),
      (1, 3),
      (1, 4),
      (1, 5),
      (2, 3),
      (2, 4),
      (2, 5),
    ]),
    // a tree that defeats naive greedy
    @graph.from_edges_undirected([
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 5),
      (5, 6),
      (2, 7),
      (4, 8),
    ]),
    // two blossoms sharing a stem
    @graph.from_edges_undirected([
      (0, 1),
      (1, 2),
      (2, 0),
      (2, 3),
      (3, 4),
      (4, 5),
      (5, 3),
    ]),
  ]
  let sizes : Array[Int] = []
  for g in graphs {
    let m = @algo.maximum_matching(g)
    assert_valid_matching(g, m)
    assert_eq(m.len(), brute_force_max_matching(g))
    // The greedy matching is never larger than the maximum one.
    assert_true(@algo.greedy_matching(g).len() <= m.len())
    sizes.push(m.len())
  }
  json_inspect(sizes, content=[2, 3, 3, 5, 2, 3, 4, 3])
}
