///|
/// An edge-reversing graph adaptor.
///
/// All edges have the opposite direction with `Reversed`: an outgoing neighbor
/// of `a` in `Reversed(g)` is an incoming neighbor of `a` in `g`, and vice
/// versa. The adaptor is a *view*: it copies nothing and keeps the node ids of
/// the underlying graph, so it composes with every traversal that is generic
/// over `@graph.NeighborSource` (`Dfs`, `Bfs`, `DfsPostOrder`, `Topo`,
/// `depth_first_search`).
///
/// # Example
/// ```mbt check
/// test {
///   // 0 -> 1 -> 2; reversed, node 2 reaches 1 and 0.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
///   let r = @visit.Reversed(g)
///   let dfs = @visit.Dfs::new(r, @graph.NodeId::new(2))
///   let order = []
///   while dfs.next(r) is Some(n) {
///     order.push(n.index())
///   }
///   debug_inspect(order, content="[2, 1, 0]")
/// }
/// ```
pub(all) struct Reversed[G](G)

///|
/// The number of nodes is unchanged by reversing the edges.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for Reversed[G] with fn node_count(
  self,
) {
  self.0.node_count()
}

///|
/// The node set is unchanged by reversing the edges.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for Reversed[G] with fn node_ids(
  self,
) {
  self.0.node_ids()
}

///|
/// Neighbors in direction `dir` are the underlying graph's neighbors in the
/// opposite direction, mirroring petgraph's `IntoNeighborsDirected for
/// Reversed<G>`.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for Reversed[G] with fn neighbors_directed(
  self,
  a,
  dir,
) {
  self.0.neighbors_directed(a, dir.opposite())
}
