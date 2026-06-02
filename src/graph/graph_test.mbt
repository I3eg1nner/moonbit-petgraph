///|
/// Helper: render an array of NodeId as their integer indices.
fn node_indices(xs : Array[@graph.NodeId]) -> Array[Int] {
  [
    for x in xs => x.index()
  ]
}

///|
/// Helper: render an array of EdgeId as their integer indices.
fn edge_indices(xs : Array[@graph.EdgeId]) -> Array[Int] {
  [
    for x in xs => x.index()
  ]
}

///|
test "construction: directed vs undirected, counts" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  debug_inspect(g.is_directed(), content="true")
  debug_inspect(g.node_count(), content="0")
  debug_inspect(g.edge_count(), content="0")
  let u : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  debug_inspect(u.is_directed(), content="false")
  let c : @graph.Graph[Int, Int] = @graph.Graph::with_capacity(4, 8)
  debug_inspect(c.is_directed(), content="true")
}

///|
test "add nodes and edges, weights and endpoints" {
  let g : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = g.add_node("a")
  let b = g.add_node("b")
  let c = g.add_node("c")
  debug_inspect(a.index(), content="0")
  debug_inspect(b.index(), content="1")
  debug_inspect(c.index(), content="2")
  debug_inspect(g.node_count(), content="3")
  let e0 = g.add_edge(a, b, 10)
  let e1 = g.add_edge(b, c, 20)
  debug_inspect(e0.index(), content="0")
  debug_inspect(e1.index(), content="1")
  debug_inspect(g.edge_count(), content="2")
  debug_inspect(
    g.node_weight(a),
    content=(
      #|Some("a")
    ),
  )
  debug_inspect(g.node_weight(@graph.NodeId::new(99)), content="None")
  debug_inspect(g.edge_weight(e0), content="Some(10)")
  // endpoints
  match g.edge_endpoints(e1) {
    Some((s, t)) => {
      debug_inspect(s.index(), content="1")
      debug_inspect(t.index(), content="2")
    }
    None => fail("expected endpoints")
  }
  // set node / edge weights
  g.set_node_weight(a, "A")
  debug_inspect(
    g.node_weight(a),
    content=(
      #|Some("A")
    ),
  )
  g.set_edge_weight(e0, 11)
  debug_inspect(g.edge_weight(e0), content="Some(11)")
}

///|
test "update_edge updates existing, adds new" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let e0 = g.update_edge(a, b, 5)
  debug_inspect(g.edge_count(), content="1")
  debug_inspect(g.edge_weight(e0), content="Some(5)")
  // same endpoints: updates weight, same edge id
  let e0b = g.update_edge(a, b, 7)
  debug_inspect(e0b.index(), content="0")
  debug_inspect(g.edge_count(), content="1")
  debug_inspect(g.edge_weight(e0), content="Some(7)")
  // new endpoints: adds
  let e1 = g.update_edge(b, a, 9)
  debug_inspect(e1.index(), content="1")
  debug_inspect(g.edge_count(), content="2")
}

///|
test "find_edge directed and undirected" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let _ = g.add_edge(a, b, 1)
  // directed: a->b exists, b->a does not
  debug_inspect(g.find_edge(a, b).map(e => e.index()), content="Some(0)")
  debug_inspect(g.find_edge(b, a), content="None")
  debug_inspect(g.contains_edge(a, b), content="true")
  debug_inspect(g.contains_edge(b, a), content="false")
  // find_edge_undirected on a directed graph: a->b found Outgoing,
  // querying b,a finds the same edge as Incoming.
  match g.find_edge_undirected(b, a) {
    Some((e, d)) => {
      debug_inspect(e.index(), content="0")
      debug_inspect(d, content="Incoming")
    }
    None => fail("expected undirected edge")
  }
  // undirected graph: edge is symmetric for find_edge
  let u : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let x = u.add_node(0)
  let y = u.add_node(0)
  let _ = u.add_edge(x, y, 1)
  debug_inspect(u.find_edge(x, y).map(e => e.index()), content="Some(0)")
  debug_inspect(u.find_edge(y, x).map(e => e.index()), content="Some(0)")
}

///|
test "neighbors order: reverse insertion, directed" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let c = g.add_node(0)
  let d = g.add_node(0)
  // a -> b, a -> c, a -> d in that order
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(a, c, 0)
  let _ = g.add_edge(a, d, 0)
  // most recently added first: d, c, b
  debug_inspect(node_indices(g.neighbors(a)), content="[3, 2, 1]")
  // incoming neighbors of c: just a
  debug_inspect(node_indices(g.neighbors_directed(c, Incoming)), content="[0]")
  // outgoing neighbors of c: none
  debug_inspect(node_indices(g.neighbors_directed(c, Outgoing)), content="[]")
}

///|
test "neighbors undirected and self-loop skip" {
  let u : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let a = u.add_node(0)
  let b = u.add_node(0)
  let _ = u.add_edge(a, b, 0)
  // self loop on a
  let _ = u.add_edge(a, a, 0)
  // undirected neighbors of a: outgoing list yields targets [a (self), b];
  // incoming list yields sources but the self-loop is skipped to avoid double
  // counting. Outgoing edges added: e0(a->b), e1(a->a). Outgoing head walk
  // (reverse insertion): e1 -> target a, e0 -> target b  => [a, b].
  // Incoming head walk: e1 (a->a) skipped (src==a), then edges to a: none here.
  debug_inspect(node_indices(u.neighbors_undirected(a)), content="[0, 1]")
}

///|
test "edges_directed order" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let c = g.add_node(0)
  let e0 = g.add_edge(a, b, 0)
  let e1 = g.add_edge(a, c, 0)
  // outgoing edges of a in reverse insertion order: e1, e0
  debug_inspect(edge_indices(g.edges_directed(a, Outgoing)), content="[1, 0]")
  debug_inspect(e0.index(), content="0")
  debug_inspect(e1.index(), content="1")
  // incoming edges of b: e0
  debug_inspect(edge_indices(g.edges_directed(b, Incoming)), content="[0]")
}

///|
test "externals" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let _c = g.add_node(0)
  let _ = g.add_edge(a, b, 0)
  // sources (no incoming): a and c
  debug_inspect(node_indices(g.externals(Incoming)), content="[0, 2]")
  // sinks (no outgoing): b and c
  debug_inspect(node_indices(g.externals(Outgoing)), content="[1, 2]")
}

///|
test "node_ids and edge_ids" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let _ = g.add_edge(a, b, 0)
  debug_inspect(node_indices(g.node_ids()), content="[0, 1]")
  debug_inspect(edge_indices(g.edge_ids()), content="[0]")
}

///|
test "from_edges directed auto-creates nodes" {
  let g = @graph.from_edges([(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)])
  debug_inspect(g.is_directed(), content="true")
  debug_inspect(g.node_count(), content="4")
  debug_inspect(g.edge_count(), content="6")
  // node weights are own index
  debug_inspect(g.node_weight(@graph.NodeId::new(3)), content="Some(3)")
  // outgoing neighbors of 0 in reverse insertion: 3, 2, 1
  debug_inspect(
    node_indices(g.neighbors(@graph.NodeId::new(0))),
    content="[3, 2, 1]",
  )
}

///|
test "from_edges_undirected" {
  let g = @graph.from_edges_undirected([(0, 1), (1, 2)])
  debug_inspect(g.is_directed(), content="false")
  debug_inspect(g.node_count(), content="3")
  // undirected: node 1 is connected to both 0 and 2
  debug_inspect(
    node_indices(g.neighbors(@graph.NodeId::new(1))),
    content="[2, 0]",
  )
}

///|
test "reverse flips edge direction" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let _ = g.add_edge(a, b, 0)
  // before: a -> b
  debug_inspect(node_indices(g.neighbors_directed(a, Outgoing)), content="[1]")
  debug_inspect(node_indices(g.neighbors_directed(a, Incoming)), content="[]")
  g.reverse()
  // after: b -> a, so a has incoming from b and no outgoing
  debug_inspect(node_indices(g.neighbors_directed(a, Outgoing)), content="[]")
  debug_inspect(node_indices(g.neighbors_directed(a, Incoming)), content="[1]")
  match g.edge_endpoints(@graph.EdgeId::new(0)) {
    Some((s, t)) => {
      debug_inspect(s.index(), content="1")
      debug_inspect(t.index(), content="0")
    }
    None => fail("expected endpoints")
  }
}

///|
test "clear and clear_edges" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let _ = g.add_edge(a, b, 0)
  g.clear_edges()
  debug_inspect(g.node_count(), content="2")
  debug_inspect(g.edge_count(), content="0")
  debug_inspect(node_indices(g.neighbors(a)), content="[]")
  g.clear()
  debug_inspect(g.node_count(), content="0")
}

///|
test "remove_edge returns weight and keeps structure" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(0)
  let c = g.add_node(0)
  let e0 = g.add_edge(a, b, 100)
  let _ = g.add_edge(a, c, 200)
  // remove the first edge; last edge (a->c) swaps into slot 0
  debug_inspect(g.remove_edge(e0), content="Some(100)")
  debug_inspect(g.edge_count(), content="1")
  // a now only connects to c
  debug_inspect(node_indices(g.neighbors(a)), content="[2]")
  // the surviving edge weight is 200 and lives at index 0 now
  debug_inspect(g.edge_weight(@graph.EdgeId::new(0)), content="Some(200)")
}

///|
test "remove_node returns weight and removes incident edges" {
  let g : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = g.add_node("a")
  let b = g.add_node("b")
  let c = g.add_node("c")
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, c, 0)
  let _ = g.add_edge(c, a, 0)
  // remove b: edges a->b and b->c go away; c->a remains.
  // swap: last node c moves into b's slot (index 1).
  debug_inspect(
    g.remove_node(b),
    content=(
      #|Some("b")
    ),
  )
  debug_inspect(g.node_count(), content="2")
  debug_inspect(g.edge_count(), content="1")
  // node at index 1 is now c (weight "c")
  debug_inspect(
    g.node_weight(@graph.NodeId::new(1)),
    content=(
      #|Some("c")
    ),
  )
  // remaining edge connects c(now idx1) -> a(idx0)
  match g.edge_endpoints(@graph.EdgeId::new(0)) {
    Some((s, t)) => {
      debug_inspect(s.index(), content="1")
      debug_inspect(t.index(), content="0")
    }
    None => fail("expected endpoints")
  }
}
