///|
/// Walk the adjacency list of every node in direction `d` and assert that:
/// - every traversed EdgeId is in bounds (no dangling pointer),
/// - the chain terminates at the `end` sentinel (no cycles / no overrun),
/// - each edge's endpoint in direction `d` points back at the node we started
///   the walk from (intrusive list consistency).
fn[N, E] Graph::check_dir(self : Graph[N, E], d : Direction) -> Unit raise {
  let n = self.nodes.length()
  let m = self.edges.length()
  for i in 0..<n {
    let node = self.nodes[i]
    let start = node.next(d)
    let mut cur = start
    // bound on iterations to catch cycles
    let mut steps = 0
    while !cur.is_end() {
      let idx = cur.index()
      // in bounds
      guard idx >= 0 && idx < m else {
        fail("dangling edge id \{idx} in node \{i} dir \{d.index()}")
      }
      let edge = self.edges[idx]
      // endpoint in this direction must be node i
      let endpoint = edge.node(d)
      guard endpoint.index() == i else {
        fail(
          "edge \{idx} endpoint dir \{d.index()} is \{endpoint.index()}, expected \{i}",
        )
      }
      cur = edge.next(d)
      steps = steps + 1
      guard steps <= m else { fail("cycle in adjacency list of node \{i}") }
    }
  }
}

///|
/// Full invariant check across both directions, plus src/dst in bounds.
fn[N, E] Graph::check_invariants(self : Graph[N, E]) -> Unit raise {
  let n = self.nodes.length()
  for i in 0..<self.edges.length() {
    let e = self.edges[i]
    guard e.src.index() >= 0 && e.src.index() < n else {
      fail("edge \{i} src out of bounds: \{e.src.index()}")
    }
    guard e.dst.index() >= 0 && e.dst.index() < n else {
      fail("edge \{i} dst out of bounds: \{e.dst.index()}")
    }
  }
  self.check_dir(Outgoing)
  self.check_dir(Incoming)
}

///|
test "invariants after remove middle node (forces swap)" {
  let g : Graph[Int, Int] = Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let d = g.add_node(3)
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, c, 0)
  let _ = g.add_edge(c, d, 0)
  let _ = g.add_edge(a, c, 0)
  let _ = g.add_edge(d, b, 0)
  // remove b (middle) -> d swaps into b's slot
  let _ = g.remove_node(b)
  g.check_invariants()
  debug_inspect(g.node_count(), content="3")
}

///|
test "invariants after remove last node" {
  let g : Graph[Int, Int] = Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, c, 0)
  let _ = g.add_edge(a, c, 0)
  // remove the last node c (no swap relocation)
  let _ = g.remove_node(c)
  g.check_invariants()
  debug_inspect(g.node_count(), content="2")
  debug_inspect(g.edge_count(), content="1")
}

///|
test "invariants with self loops, then remove" {
  let g : Graph[Int, Int] = Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let _ = g.add_edge(a, a, 0) // self loop
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, b, 0) // self loop
  g.check_invariants()
  // remove a: self-loop on a and a->b removed; b's self loop remains.
  let _ = g.remove_node(a)
  g.check_invariants()
  debug_inspect(g.node_count(), content="1")
  // only b's self-loop survives
  debug_inspect(g.edge_count(), content="1")
}

///|
test "invariants after several remove_edge orderings" {
  let g : Graph[Int, Int] = Graph::new()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let e0 = g.add_edge(a, b, 0)
  let _ = g.add_edge(a, c, 0)
  let e2 = g.add_edge(b, c, 0)
  let _ = g.add_edge(c, a, 0)
  // remove a middle edge (forces swap of last edge into its slot)
  let _ = g.remove_edge(e0)
  g.check_invariants()
  // remove what is now possibly relocated; remove e2's original weight target
  let _ = g.remove_edge(e2)
  g.check_invariants()
  debug_inspect(g.edge_count(), content="2")
}

///|
test "invariants on undirected graph after removals" {
  let g : Graph[Int, Int] = Graph::new_undirected()
  let a = g.add_node(0)
  let b = g.add_node(1)
  let c = g.add_node(2)
  let _ = g.add_edge(a, b, 0)
  let _ = g.add_edge(b, c, 0)
  let _ = g.add_edge(a, c, 0)
  let _ = g.add_edge(a, a, 0)
  g.check_invariants()
  let _ = g.remove_node(b)
  g.check_invariants()
  debug_inspect(g.node_count(), content="2")
}
