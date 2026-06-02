///|
/// Map a sequence of node ids to their integer indices for snapshot comparison.
fn ids_to_ints(ids : Iter[@graph.NodeId]) -> Array[Int] {
  [
    for id in ids => id.index()
  ]
}

///|
/// Drain a `Dfs` walker into the list of visited node indices.
fn collect_dfs(dfs : @visit.Dfs, g : @graph.Graph[Int, Unit]) -> Array[Int] {
  let out = []
  while dfs.next(g) is Some(n) {
    out.push(n.index())
  }
  out
}

///|
/// The shared example DAG: 0->1, 0->2, 1->3, 2->3.
///
/// petgraph (and this port) yield neighbors in reverse insertion order, so
/// node 0's outgoing neighbors are [2, 1].
fn sample_dag() -> @graph.Graph[Int, Unit] {
  @graph.from_edges([(0, 1), (0, 2), (1, 3), (2, 3)])
}

///|
test "neighbors are reverse-insertion order" {
  let g = sample_dag()
  json_inspect(ids_to_ints(g.neighbors(@graph.NodeId::new(0))), content=[2, 1])
}

///|
test "Dfs preorder on the sample DAG" {
  let g = sample_dag()
  let dfs = @visit.Dfs::new(g, @graph.NodeId::new(0))
  // Stack pushes [2,1]; pop 1 -> push [3]; pop 3; pop 2 (3 already seen).
  json_inspect(collect_dfs(dfs, g), content=[0, 1, 3, 2])
}

///|
test "Bfs order on the sample DAG" {
  let g = sample_dag()
  let bfs = @visit.Bfs::new(g, @graph.NodeId::new(0))
  let out = []
  while bfs.next(g) is Some(n) {
    out.push(n.index())
  }
  // Queue: enqueue [2,1]; 2 -> enqueue 3; 1 -> 3 already seen; then 3.
  json_inspect(out, content=[0, 2, 1, 3])
}

///|
test "DfsPostOrder on the sample DAG" {
  let g = sample_dag()
  let dfs = @visit.DfsPostOrder::new(g, @graph.NodeId::new(0))
  let out = []
  while dfs.next(g) is Some(n) {
    out.push(n.index())
  }
  // Descendants finish before ancestors: 3, then 1, then 2, then 0.
  json_inspect(out, content=[3, 1, 2, 0])
}

///|
test "Topo order on the sample DAG" {
  let g = sample_dag()
  let topo = @visit.Topo::new(g)
  let out = []
  while topo.next(g) is Some(n) {
    out.push(n.index())
  }
  json_inspect(out, content=[0, 1, 2, 3])
}

///|
test "Topo skips nodes on a cycle" {
  // 0 -> 1 (a DAG part); 2 <-> 3 form a cycle with no acyclic entry.
  let g = @graph.from_edges([(0, 1), (2, 3), (3, 2)])
  let topo = @visit.Topo::new(g)
  let out = []
  while topo.next(g) is Some(n) {
    out.push(n.index())
  }
  // Only the acyclic part (0, 1) is yielded; 2 and 3 are stuck in the cycle.
  json_inspect(out, content=[0, 1])
  // A complete topo order would have all 4 nodes; it does not, so the graph is
  // not a DAG.
  assert_eq(out.length() < g.node_count(), true)
}

///|
test "Dfs reset and move_to" {
  let g = sample_dag()
  let dfs = @visit.Dfs::new(g, @graph.NodeId::new(0))
  let _ = collect_dfs(dfs, g)
  // After draining, reset and start over from node 2.
  dfs.reset()
  dfs.move_to(@graph.NodeId::new(2))
  json_inspect(collect_dfs(dfs, g), content=[2, 3])
}
