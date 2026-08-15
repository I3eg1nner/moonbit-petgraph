///|
/// An edge-direction removing graph adaptor.
///
/// `UndirectedAdaptor` presents a directed graph as an undirected one: the
/// neighbors of `a` are its incoming neighbors followed by its outgoing
/// neighbors, whichever direction is asked for. A directed path is therefore
/// traversable from either end.
///
/// # Example
/// ```mbt check
/// test {
///   // The directed path 0 -> 1 -> 2 is reachable backwards from node 2.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
///   let u = @visit.UndirectedAdaptor(g)
///   let dfs = @visit.Dfs::new(u, @graph.NodeId::new(2))
///   let order = []
///   while dfs.next(u) is Some(n) {
///     order.push(n.index())
///   }
///   debug_inspect(order, content="[2, 1, 0]")
/// }
/// ```
pub(all) struct UndirectedAdaptor[G](G)

///|
/// Dropping edge directions does not change the node set.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for UndirectedAdaptor[
  G,
] with fn node_count(self) {
  self.0.node_count()
}

///|
/// Dropping edge directions does not change the node set.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for UndirectedAdaptor[
  G,
] with fn node_ids(self) {
  self.0.node_ids()
}

///|
/// Neighbors in *both* directions, whichever direction was requested: the
/// incoming neighbors chained with the outgoing ones, exactly as petgraph's
/// `IntoNeighbors for UndirectedAdaptor<G>` does.
///
/// Deviation from petgraph: upstream only provides `IntoNeighbors` (an
/// undirected graph has no notion of direction), while this port's single
/// `NeighborSource` trait always takes a direction, so the argument is ignored
/// here.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for UndirectedAdaptor[
  G,
] with fn neighbors_directed(self, a, _dir) {
  self.0
  .neighbors_directed(a, Incoming)
  .concat(self.0.neighbors_directed(a, Outgoing))
}
