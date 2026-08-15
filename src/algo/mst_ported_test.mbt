// Ported from petgraph's REAL tests/min_spanning_tree.rs. Only Kruskal's
// `min_spanning_tree` is in scope (prim is OUT OF SCOPE), but the MST edge set
// is identical, so the prim-only graphs are still exercised via Kruskal.
//
// API-shape adaptation: petgraph builds a new UnGraph from the element stream
// and checks node_count / edge_count / find_edge. OURS returns an
// `Array[EdgeId]` (the chosen MST edges). We adapt by checking the edge count
// (== node_count - #components) and that each expected edge is present, using
// the endpoints of the returned EdgeIds (undirected, so either direction).
// Original Rust test names are preserved as annotations.

///|
/// Collect the undirected endpoint pairs (min,max index) of the MST edges.
fn mst_pairs(
  g : @graph.Graph[Int, Double],
  mst : Array[@graph.EdgeId],
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for e in mst {
    guard! g.edge_endpoints(e) is Some((s, t))
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
/// Whether the MST contains an (undirected) edge between `a` and `b`.
fn mst_has(pairs : Array[(Int, Int)], a : Int, b : Int) -> Bool {
  let lo = if a < b { a } else { b }
  let hi = if a < b { b } else { a }
  pairs.iter().any(p => p.0 == lo && p.1 == hi)
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_kruskal`
test "mst_kruskal" {
  // A=0 B=1 C=2 D=3 E=4 F=5 G=6, disjoint H=7 I=8 J=9.
  let gr : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
  for _i in 0..<7 {
    gr.add_node(gr.node_count()) |> ignore
  }
  let edges : Array[(Int, Int, Double)] = [
    (0, 1, 7.0),
    (0, 3, 5.0),
    (3, 1, 9.0),
    (1, 2, 8.0),
    (1, 4, 7.0),
    (2, 4, 5.0),
    (3, 4, 15.0),
    (3, 5, 6.0),
    (5, 4, 8.0),
    (5, 6, 11.0),
    (4, 6, 9.0),
  ]
  for e in edges {
    gr.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  // disjoint part
  for _i in 0..<3 {
    gr.add_node(gr.node_count()) |> ignore
  }
  for e in [(7, 8, 1.0), (7, 9, 3.0), (8, 9, 1.0)] {
    gr.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  let mst = @algo.min_spanning_tree(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  // |E| = |N| - 2 because there are two disconnected components.
  inspect(mst.length(), content="8")
  let pairs = mst_pairs(gr, mst)
  // exact MST edges present
  inspect(mst_has(pairs, 0, 1), content="true")
  inspect(mst_has(pairs, 0, 3), content="true")
  inspect(mst_has(pairs, 1, 4), content="true")
  inspect(mst_has(pairs, 4, 2), content="true")
  inspect(mst_has(pairs, 4, 6), content="true")
  inspect(mst_has(pairs, 3, 5), content="true")
  inspect(mst_has(pairs, 7, 8), content="true")
  inspect(mst_has(pairs, 8, 9), content="true")
  // edges that must NOT be in the MST
  inspect(mst_has(pairs, 3, 1), content="false")
  inspect(mst_has(pairs, 1, 2), content="false")
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_trivial_graph`
/// (prim is out of scope; Kruskal yields the same single-edge MST.)
test "mst_prim_trivial_graph (via kruskal)" {
  let gr : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
  let a = gr.add_node(0)
  let b = gr.add_node(1)
  let w = 7.0
  gr.add_edge(a, b, w) |> ignore
  let mst = @algo.min_spanning_tree(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  inspect(mst.length(), content="1")
  inspect(mst_has(mst_pairs(gr, mst), 0, 1), content="true")
  inspect(gr.edge_weight(mst[0]).unwrap(), content="7")
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_graph_without_edges`
test "mst_prim_graph_without_edges (via kruskal)" {
  let gr : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
  for _i in 0..<7 {
    gr.add_node(gr.node_count()) |> ignore
  }
  let mst = @algo.min_spanning_tree(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  inspect(mst.length(), content="0")
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_prim_empty_graph`
test "mst_prim_empty_graph (via kruskal)" {
  let gr : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
  let mst = @algo.min_spanning_tree(gr, edge_cost=e => {
    gr.edge_weight(e).unwrap()
  })
  inspect(mst.length(), content="0")
}

///|
/// petgraph test: tests/min_spanning_tree.rs `mst_kruskal_test_cases`.
/// The four parametrized cases. Builds an undirected graph from u32 weights,
/// then checks edge count == #expected and each expected edge is present.
test "mst_kruskal_test_cases" {
  // (order, edges, expected_mst_edges)
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
    let gr : @graph.Graph[Int, Double] = @graph.Graph::new_undirected()
    for _i in 0..<order {
      gr.add_node(gr.node_count()) |> ignore
    }
    for e in edges {
      gr.add_edge(
        @graph.NodeId::new(e.0),
        @graph.NodeId::new(e.1),
        e.2.to_double(),
      )
      |> ignore
    }
    let mst = @algo.min_spanning_tree(gr, edge_cost=e => {
      gr.edge_weight(e).unwrap()
    })
    assert_eq(mst.length(), expected.length())
    let pairs = mst_pairs(gr, mst)
    for ex in expected {
      assert_eq(mst_has(pairs, ex.0, ex.1), true)
    }
  }
}
