// Tests for the structural algorithms: toposort, is_cyclic_directed,
// is_cyclic_undirected, connected_components, kosaraju_scc, tarjan_scc, and the
// cross-checks between them.

///|
/// Sort each SCC's node ids, then sort the list of SCCs by their (sorted)
/// contents, so the result is canonical and stable for snapshotting regardless
/// of internal traversal order.
fn canon_sccs(sccs : Array[Array[@graph.NodeId]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  for scc in sccs {
    let inner = [ for n in scc => n.index() ]
    inner.sort()
    out.push(inner)
  }
  out.sort_by((a, b) => {
    let la = a.length()
    let lb = b.length()
    let m = if la < lb { la } else { lb }
    for i in 0..<m {
      if a[i] != b[i] {
        return a[i].compare(b[i])
      }
    }
    la.compare(lb)
  })
  out
}

///|
test "toposort on a DAG: each edge goes source-before-target" {
  // A DAG: 0->1, 0->2, 1->3, 2->3, 3->4
  let g = @graph.from_edges([(0, 1), (0, 2), (1, 3), (2, 3), (3, 4)])
  let order = @algo.toposort(g) catch {
    _ => {
      fail("expected acyclic graph")
      []
    }
  }
  // Build position index for each node, then assert every edge respects order.
  let pos = Array::make(g.node_count(), -1)
  for i, n in order {
    pos[n.index()] = i
  }
  json_inspect([ for n in order => n.index() ], content=[0, 1, 2, 3, 4])
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((s, t))
    assert_eq(pos[s.index()] < pos[t.index()], true)
  }
}

///|
test "toposort returns Err on a cyclic graph" {
  // 0 -> 1 -> 2 -> 0 is a cycle.
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 0)])
  let is_err = try @algo.toposort(g) catch {
    Cycle(node) => {
      // The reported node must be one of the cycle members 0,1,2.
      let idx = node.index()
      assert_eq(idx >= 0 && idx <= 2, true)
      true
    }
  } noraise {
    _ => false
  }
  inspect(is_err, content="true")
}

///|
test "is_cyclic_directed true iff toposort is Err (several graphs)" {
  let dag = @graph.from_edges([(0, 1), (1, 2), (0, 2)])
  let cyclic = @graph.from_edges([(0, 1), (1, 2), (2, 0)])
  let self_loop = @graph.from_edges([(0, 0)])
  for g in [dag, cyclic, self_loop] {
    let cyc = @algo.is_cyclic_directed(g)
    let topo_err = try @algo.toposort(g) catch {
      _ => true
    } noraise {
      _ => false
    }
    assert_eq(cyc, topo_err)
  }
  // Spot-check the actual values.
  json_inspect(
    [
      @algo.is_cyclic_directed(dag),
      @algo.is_cyclic_directed(cyclic),
      @algo.is_cyclic_directed(self_loop),
    ],
    content=[false, true, true],
  )
}

///|
test "is_cyclic_undirected via union-find" {
  // Tree (no cycle) vs. graph with a cycle when treated as undirected.
  let tree = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3)])
  let with_cycle = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 0)])
  inspect(@algo.is_cyclic_undirected(tree), content="false")
  inspect(@algo.is_cyclic_undirected(with_cycle), content="true")
}

///|
test "connected_components counts undirected components" {
  // Two components: {0,1,2,3} and {4,5,6,7}; matches petgraph doc example.
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
  // Adding an edge bridging them makes it 1.
  g.add_edge(@graph.NodeId::new(1), @graph.NodeId::new(4), ()) |> ignore
  inspect(@algo.connected_components(g), content="1")
}

///|
test "kosaraju_scc on two-cycle graph (reverse-topological order)" {
  // Two SCCs: {0,1,2} and {3,4,5}, with edge c(2)->d(3) between them.
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
  // Two components, each of size 3.
  inspect(sccs.length(), content="2")
  json_inspect(canon_sccs(sccs), content=[[0, 1, 2], [3, 4, 5]])
  // Ordering: SCCs are in reverse topological order, so the sink SCC {3,4,5}
  // (no outgoing edges to other SCCs) comes FIRST.
  let first : Array[Int] = [ for n in sccs[0] => n.index() ]
  first.sort()
  json_inspect(first, content=[3, 4, 5])
}

///|
test "kosaraju_scc on a DAG: each node its own SCC" {
  let g = @graph.from_edges([(0, 1), (1, 2)])
  let sccs = @algo.kosaraju_scc(g)
  inspect(sccs.length(), content="3")
  json_inspect(canon_sccs(sccs), content=[[0], [1], [2]])
}

///|
test "tarjan_scc matches kosaraju_scc (count and contents)" {
  let g = @graph.from_edges([
    (0, 1),
    (1, 2),
    (2, 0),
    (1, 3),
    (3, 4),
    (4, 3),
    (4, 5),
  ])
  let k = @algo.kosaraju_scc(g)
  let t = @algo.tarjan_scc(g)
  assert_eq(k.length(), t.length())
  // Canonical contents must be identical.
  @test.assert_eq(canon_sccs(t), canon_sccs(k))
  // SCCs present: {0,1,2}, {3,4}, {5}
  json_inspect(canon_sccs(t), content=[[0, 1, 2], [3, 4], [5]])
}

///|
test "tarjan_scc reverse-topological ordering" {
  // 0->1->2 chain: reverse topo order means sink (2) first, source (0) last.
  let g = @graph.from_edges([(0, 1), (1, 2)])
  let t = @algo.tarjan_scc(g)
  let idxs = [ for scc in t => scc[0].index() ]
  json_inspect(idxs, content=[2, 1, 0])
}

///|
test "cross-check: connected_components == kosaraju SCC count on symmetric graph" {
  // Build a directed graph that is symmetric (every edge has its reverse), so
  // SCCs == undirected connected components.
  let base = [(0, 1), (1, 2), (3, 4)]
  let sym : Array[(Int, Int)] = []
  for e in base {
    sym.push(e)
    sym.push((e.1, e.0))
  }
  let g = @graph.from_edges(sym)
  let undirected = @graph.from_edges_undirected(base)
  let cc = @algo.connected_components(undirected)
  let scc_count = @algo.kosaraju_scc(g).length()
  assert_eq(cc, scc_count)
  json_inspect([cc, scc_count], content=[2, 2])
}

///|
test "min_spanning_tree (Kruskal) selects lightest forest edges" {
  // petgraph MST doc example weights; undirected. Expected MST weights sorted:
  // [1,1,1,2,4] and 5 edges (node_count-1 = 5 for 6 connected nodes).
  // a=0 b=1 c=2 d=3 e=4 f=5
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  for _i in 0..<6 {
    g.add_node(g.node_count()) |> ignore
  }
  let edges = [
    (0, 1, 2),
    (0, 3, 4),
    (1, 2, 1),
    (1, 5, 7),
    (2, 4, 5),
    (4, 5, 1),
    (3, 4, 1),
  ]
  for e in edges {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  let mst = @algo.min_spanning_tree(g, edge_cost=e => g.edge_weight(e).unwrap())
  inspect(mst.length(), content="5")
  let weights = [ for e in mst => g.edge_weight(e).unwrap() ]
  weights.sort()
  json_inspect(weights, content=[1, 1, 1, 2, 4])
}

///|
test "min_spanning_tree on disconnected graph yields a forest" {
  // Two components: {0,1,2} and {3,4}. MST forest has (3-1)+(2-1)=3 edges.
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  for _i in 0..<5 {
    g.add_node(g.node_count()) |> ignore
  }
  let edges = [(0, 1, 5), (1, 2, 3), (0, 2, 4), (3, 4, 2)]
  for e in edges {
    g.add_edge(@graph.NodeId::new(e.0), @graph.NodeId::new(e.1), e.2) |> ignore
  }
  let mst = @algo.min_spanning_tree(g, edge_cost=e => g.edge_weight(e).unwrap())
  inspect(mst.length(), content="3")
  let weights = [ for e in mst => g.edge_weight(e).unwrap() ]
  weights.sort()
  // Component 1 keeps edges weight 3 and 4 (drops the weight-5 redundant edge);
  // component 2 keeps weight 2.
  json_inspect(weights, content=[2, 3, 4])
}
