///|
/// The linear digraph 0 -> 1 -> 2 -> 3 -> 4 -> 5, petgraph's `LINEAR_EDGES`.
fn linear_digraph() -> @graph.Graph[Int, Unit] {
  @graph.from_edges([(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)])
}

///|
/// Drain an iterator of node ids into the list of node indices.
fn collect_ints(ids : Iter[@graph.NodeId]) -> Array[Int] {
  ids.map(n => n.index()).collect()
}

// -- Reversed ----------------------------------------------------------------

///|
test "Reversed swaps Outgoing and Incoming" {
  let g = sample_dag()
  let r = @visit.Reversed(g)
  let n3 = @graph.NodeId::new(3)
  // In `g`, node 3 has no outgoing edges and two incoming ones (from 1 and 2,
  // yielded in reverse insertion order).
  json_inspect(ids_to_ints(g.neighbors_directed(n3, Outgoing)), content=[])
  json_inspect(ids_to_ints(g.neighbors_directed(n3, Incoming)), content=[2, 1])
  // In the view they are swapped.
  json_inspect(ids_to_ints(r.neighbors_directed(n3, Outgoing)), content=[2, 1])
  json_inspect(ids_to_ints(r.neighbors_directed(n3, Incoming)), content=[])
  // The node set is untouched.
  assert_eq(r.node_count(), 4)
  json_inspect(ids_to_ints(r.node_ids()), content=[0, 1, 2, 3])
}

///|
test "Dfs over Reversed walks the sample DAG backwards" {
  let g = sample_dag()
  let r = @visit.Reversed(g)
  let dfs = @visit.Dfs::new(r, @graph.NodeId::new(3))
  let out = []
  while dfs.next(r) is Some(n) {
    out.push(n.index())
  }
  // Stack [2,1]; pop 1 -> push 0; pop 0 (no reverse-neighbors); pop 2 (0 seen).
  json_inspect(out, content=[3, 1, 0, 2])
}

///|
test "Bfs over Reversed walks the sample DAG backwards" {
  let g = sample_dag()
  let r = @visit.Reversed(g)
  let bfs = @visit.Bfs::new(r, @graph.NodeId::new(3))
  let out = []
  while bfs.next(r) is Some(n) {
    out.push(n.index())
  }
  // Queue [2,1]; 2 enqueues 0; 1 sees 0 already discovered.
  json_inspect(out, content=[3, 2, 1, 0])
}

///|
test "Topo over Reversed of a DAG reverses the topological order" {
  let g = sample_dag()
  let r = @visit.Reversed(g)
  let out = collect_ints(@visit.Topo::new(r).iter(r))
  json_inspect(out, content=[3, 1, 2, 0])
  // Every node is ordered, so the reversed view is acyclic too.
  assert_eq(out.length(), g.node_count())
  // And it is a valid topological order of the reversed graph: for every edge
  // u -> v of `g`, v comes before u.
  for edge in [(0, 1), (0, 2), (1, 3), (2, 3)] {
    let (u, v) = edge
    assert_true(out.search(v).unwrap() < out.search(u).unwrap())
  }
}

// -- NodeFiltered ------------------------------------------------------------

///|
test "NodeFiltered drops nodes from node_ids and from neighbor lists" {
  let g = sample_dag()
  // Remove node 1 from the view.
  let f = @visit.NodeFiltered::from_fn(g, n => n.index() != 1)
  json_inspect(ids_to_ints(f.node_ids()), content=[0, 2, 3])
  // Node 0's neighbors are [2, 1] in `g`; 1 is filtered out.
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(0), Outgoing)),
    content=[2],
  )
  // A filtered-out node has no neighbors at all, in either direction.
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(1), Outgoing)),
    content=[],
  )
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(1), Incoming)),
    content=[],
  )
  // Node 3 keeps its incoming edge from 2 but loses the one from 1.
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(3), Incoming)),
    content=[2],
  )
  // `node_count` stays the underlying count: the visit maps are indexed by the
  // underlying node indices.
  assert_eq(f.node_count(), 4)
}

///|
test "traversals over NodeFiltered skip the removed nodes" {
  let g = sample_dag()
  let f = @visit.NodeFiltered::from_fn(g, n => n.index() != 1)
  json_inspect(
    collect_ints(@visit.Dfs::new(f, @graph.NodeId::new(0)).iter(f)),
    content=[0, 2, 3],
  )
  json_inspect(
    collect_ints(@visit.Bfs::new(f, @graph.NodeId::new(0)).iter(f)),
    content=[0, 2, 3],
  )
  // Filtering out node 2 as well leaves 3 unreachable from 0.
  let f2 = @visit.NodeFiltered::from_fn(g, n => n.index() != 1 && n.index() != 2)
  json_inspect(
    collect_ints(@visit.Dfs::new(f2, @graph.NodeId::new(0)).iter(f2)),
    content=[0],
  )
  json_inspect(ids_to_ints(f2.node_ids()), content=[0, 3])
}

// -- EdgeFiltered ------------------------------------------------------------

///|
test "EdgeFiltered drops edges but keeps every node" {
  let g = sample_dag()
  // Remove the edge 1 -> 3.
  let f = @visit.EdgeFiltered::from_fn(g, (_, src, dst) => {
    !(src.index() == 1 && dst.index() == 3)
  })
  // Nodes are untouched.
  json_inspect(ids_to_ints(f.node_ids()), content=[0, 1, 2, 3])
  assert_eq(f.node_count(), 4)
  // Node 1 has lost its only outgoing edge.
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(1), Outgoing)),
    content=[],
  )
  // Node 3 is now only reachable from 2.
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(3), Incoming)),
    content=[2],
  )
  // Node 0's outgoing edges are untouched.
  json_inspect(
    ids_to_ints(f.neighbors_directed(@graph.NodeId::new(0), Outgoing)),
    content=[2, 1],
  )
  // The DFS still reaches 3, but through 2 only.
  json_inspect(
    collect_ints(@visit.Dfs::new(f, @graph.NodeId::new(0)).iter(f)),
    content=[0, 1, 2, 3],
  )
}

///|
test "EdgeFiltered predicate can select on the edge weight" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let n = [ for i in 0..<4 => g.add_node(i) ]
  g.add_edge(n[0], n[1], 1) |> ignore
  g.add_edge(n[0], n[2], 5) |> ignore
  g.add_edge(n[2], n[3], 1) |> ignore
  g.add_edge(n[1], n[3], 5) |> ignore
  // Keep only the heavy edges; the weight is read from the captured graph.
  let f = @visit.EdgeFiltered::from_fn(g, (e, _, _) => {
    match g.edge_weight(e) {
      Some(w) => w >= 5
      None => false
    }
  })
  json_inspect(ids_to_ints(f.neighbors_directed(n[0], Outgoing)), content=[2])
  json_inspect(ids_to_ints(f.neighbors_directed(n[2], Outgoing)), content=[])
  // 0 -> 2 is heavy but 2 -> 3 is not, so the walk stops at 2.
  json_inspect(collect_ints(@visit.Dfs::new(f, n[0]).iter(f)), content=[0, 2])
}

// -- UndirectedAdaptor -------------------------------------------------------

///|
test "UndirectedAdaptor reports neighbors in both directions" {
  let g = linear_digraph()
  let u = @visit.UndirectedAdaptor(g)
  let n2 = @graph.NodeId::new(2)
  // Incoming first, then outgoing, whichever direction is asked for.
  json_inspect(ids_to_ints(u.neighbors_directed(n2, Outgoing)), content=[1, 3])
  json_inspect(ids_to_ints(u.neighbors_directed(n2, Incoming)), content=[1, 3])
  // The ends of the path have a single neighbor each.
  json_inspect(
    ids_to_ints(u.neighbors_directed(@graph.NodeId::new(0), Outgoing)),
    content=[1],
  )
  json_inspect(
    ids_to_ints(u.neighbors_directed(@graph.NodeId::new(5), Outgoing)),
    content=[4],
  )
  assert_eq(u.node_count(), 6)
  json_inspect(ids_to_ints(u.node_ids()), content=[0, 1, 2, 3, 4, 5])
}

///|
test "UndirectedAdaptor makes a directed path traversable from either end" {
  let g = linear_digraph()
  let u = @visit.UndirectedAdaptor(g)
  // Forwards from the first node.
  json_inspect(
    collect_ints(@visit.Dfs::new(u, @graph.NodeId::new(0)).iter(u)),
    content=[0, 1, 2, 3, 4, 5],
  )
  // Backwards from the last node — impossible on the directed graph.
  json_inspect(
    collect_ints(@visit.Dfs::new(u, @graph.NodeId::new(5)).iter(u)),
    content=[5, 4, 3, 2, 1, 0],
  )
  json_inspect(
    collect_ints(@visit.Dfs::new(g, @graph.NodeId::new(5)).iter(g)),
    content=[5],
  )
  // From the middle every node is reached (petgraph's `test_is_reachable`).
  let from_middle = collect_ints(
    @visit.Dfs::new(u, @graph.NodeId::new(2)).iter(u),
  )
  json_inspect(from_middle, content=[2, 3, 4, 5, 1, 0])
  from_middle.sort()
  json_inspect(from_middle, content=[0, 1, 2, 3, 4, 5])
}

// -- Walker ------------------------------------------------------------------

///|
test "Walker::iter matches the manual Dfs next loop" {
  let g = sample_dag()
  let manual = collect_dfs(@visit.Dfs::new(g, @graph.NodeId::new(0)), g)
  let walked = collect_ints(@visit.Dfs::new(g, @graph.NodeId::new(0)).iter(g))
  assert_eq(walked, manual)
  json_inspect(walked, content=[0, 1, 3, 2])
}

///|
test "Walker::iter matches the manual Bfs next loop" {
  let g = sample_dag()
  let bfs = @visit.Bfs::new(g, @graph.NodeId::new(0))
  let manual = []
  while bfs.next(g) is Some(n) {
    manual.push(n.index())
  }
  let walked = collect_ints(@visit.Bfs::new(g, @graph.NodeId::new(0)).iter(g))
  assert_eq(walked, manual)
  json_inspect(walked, content=[0, 2, 1, 3])
}

///|
test "Walker::iter matches the manual DfsPostOrder next loop" {
  let g = sample_dag()
  let dfs = @visit.DfsPostOrder::new(g, @graph.NodeId::new(0))
  let manual = []
  while dfs.next(g) is Some(n) {
    manual.push(n.index())
  }
  let walked = collect_ints(
    @visit.DfsPostOrder::new(g, @graph.NodeId::new(0)).iter(g),
  )
  assert_eq(walked, manual)
  json_inspect(walked, content=[3, 1, 2, 0])
}

///|
test "Walker::iter matches the manual Topo next loop" {
  let g = sample_dag()
  let topo = @visit.Topo::new(g)
  let manual = []
  while topo.next(g) is Some(n) {
    manual.push(n.index())
  }
  let walked = collect_ints(@visit.Topo::new(g).iter(g))
  assert_eq(walked, manual)
  json_inspect(walked, content=[0, 1, 2, 3])
}

///|
test "Walker::walk_next steps one node at a time and is single-pass" {
  let g = sample_dag()
  let walker = @visit.Dfs::new(g, @graph.NodeId::new(0)).walker(g)
  debug_inspect(walker.walk_next().unwrap().index(), content="0")
  debug_inspect(walker.walk_next().unwrap().index(), content="1")
  // The iterator picks up where the walker left off, and drains it.
  json_inspect(collect_ints(walker.iter()), content=[3, 2])
  json_inspect(collect_ints(walker.iter()), content=[])
  assert_true(walker.walk_next() is None)
}

///|
test "Walker composes with the adaptors" {
  let g = sample_dag()
  // Reversed + Walker: a DFS from the sink reaches every node.
  let r = @visit.Reversed(g)
  json_inspect(
    collect_ints(@visit.Dfs::new(r, @graph.NodeId::new(3)).iter(r)),
    content=[3, 1, 0, 2],
  )
  // NodeFiltered on top of Reversed: node 1 disappears from the reverse walk.
  let f = @visit.NodeFiltered::from_fn(r, n => n.index() != 1)
  json_inspect(
    collect_ints(@visit.Dfs::new(f, @graph.NodeId::new(3)).iter(f)),
    content=[3, 2, 0],
  )
  // UndirectedAdaptor on top of NodeFiltered: the path 0 - 2 - 3 both ways.
  let u = @visit.UndirectedAdaptor(f)
  json_inspect(
    collect_ints(@visit.Bfs::new(u, @graph.NodeId::new(0)).iter(u)),
    content=[0, 2, 3],
  )
}
