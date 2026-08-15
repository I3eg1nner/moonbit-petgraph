///|
/// Return `true` if the directed graph contains a cycle.
///
/// Port of petgraph's `algo::is_cyclic_directed`: run a depth-first search over
/// all node identifiers and report `true` as soon as a back edge is discovered.
/// A captured `Ref[Bool]` records the result, and we return `Break` from the
/// visitor on the first back edge to stop the search early.
pub fn[G : @graph.NeighborSource] is_cyclic_directed(g : G) -> Bool {
  let found = Ref(false)
  @visit.depth_first_search(g, g.node_ids().to_array(), event => {
    match event {
      BackEdge(_, _) => {
        found.val = true
        Break
      }
      _ => Continue
    }
  })
  found.val
}

///|
/// Return `true` if the graph contains a cycle, treating it as undirected.
///
/// Port of petgraph's `algo::is_cyclic_undirected`: union the endpoints of every
/// edge in a union-find; if an edge's endpoints are already in the same set, the
/// edge closes a cycle.
pub fn[N, E] is_cyclic_undirected(g : @graph.Graph[N, E]) -> Bool {
  let edge_sets = @unionfind.UnionFind::new(g.node_count())
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((a, b)) else { continue }
    if !edge_sets.union(a.index(), b.index()) {
      return true
    }
  }
  false
}

///|
/// Count the connected components of the graph, treating it as undirected.
///
/// Port of petgraph's `algo::connected_components`: union the endpoints of every
/// edge in a union-find, then count the distinct set roots.
///
/// # Example
/// ```mbt check
/// test {
///   // Two disjoint undirected edges: {0,1} and {2,3}.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges_undirected([
///     (0, 1),
///     (2, 3),
///   ])
///   debug_inspect(@algo.connected_components(g), content="2")
/// }
/// ```
pub fn[N, E] connected_components(g : @graph.Graph[N, E]) -> Int {
  let node_sets = @unionfind.UnionFind::new(g.node_count())
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((a, b)) else { continue }
    node_sets.union(a.index(), b.index()) |> ignore
  }
  let labels = node_sets.into_labeling()
  let roots : Map[Int, Unit] = Map([])
  for label in labels {
    roots[label] = ()
  }
  roots.length()
}
