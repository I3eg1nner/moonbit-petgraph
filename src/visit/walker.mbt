///|
/// A walker: a traversal that has been bound to the graph it walks, and that
/// yields one node at a time until it is exhausted.
///
/// This is the port of petgraph's `Walker` trait. Deviation: petgraph's
/// `Walker<Context>` is generic over the context (the graph) and takes it as an
/// argument of `walk_next`; MoonBit traits are neither generic over an extra
/// type parameter nor carry associated types, so a `Walker` here is simply the
/// step function with the graph captured in its closure. `Walker::iter` then
/// plays the role of `Walker::iter` + `WalkerIter`.
///
/// A `Walker` is stateful and single-pass: once drained it stays exhausted.
pub(all) struct Walker(() -> @graph.NodeId?)

///|
/// Advance to the next node, or `None` when the traversal is done.
pub fn Walker::walk_next(self : Walker) -> @graph.NodeId? {
  let step = self.0
  step()
}

///|
/// Turn the walker into a plain `Iter[@graph.NodeId]`.
///
/// The iterator is lazy and single-pass: it drives the underlying traversal, so
/// consuming it consumes the walker.
///
/// # Example
/// ```mbt check
/// test {
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
///   let walker = @visit.Dfs::new(g, @graph.NodeId::new(0)).walker(g)
///   debug_inspect(
///     walker.iter().map(n => n.index()).collect(),
///     content="[0, 1, 2]",
///   )
/// }
/// ```
pub fn Walker::iter(self : Walker) -> Iter[@graph.NodeId] {
  Iter::new(() => self.walk_next())
}

///|
/// Bind this `Dfs` to `graph`, giving a `Walker`.
pub fn[G : @graph.NeighborSource] Dfs::walker(self : Dfs, graph : G) -> Walker {
  Walker(() => self.next(graph))
}

///|
/// The remaining nodes of this DFS preorder over `graph`, as an iterator.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([
///     (0, 1),
///     (0, 2),
///     (1, 3),
///     (2, 3),
///   ])
///   let order = @visit.Dfs::new(g, @graph.NodeId::new(0))
///     .iter(g)
///     .map(n => n.index())
///     .collect()
///   debug_inspect(order, content="[0, 1, 3, 2]")
/// }
/// ```
pub fn[G : @graph.NeighborSource] Dfs::iter(
  self : Dfs,
  graph : G,
) -> Iter[@graph.NodeId] {
  self.walker(graph).iter()
}

///|
/// Bind this `Bfs` to `graph`, giving a `Walker`.
pub fn[G : @graph.NeighborSource] Bfs::walker(self : Bfs, graph : G) -> Walker {
  Walker(() => self.next(graph))
}

///|
/// The remaining nodes of this BFS over `graph`, as an iterator.
pub fn[G : @graph.NeighborSource] Bfs::iter(
  self : Bfs,
  graph : G,
) -> Iter[@graph.NodeId] {
  self.walker(graph).iter()
}

///|
/// Bind this `DfsPostOrder` to `graph`, giving a `Walker`.
pub fn[G : @graph.NeighborSource] DfsPostOrder::walker(
  self : DfsPostOrder,
  graph : G,
) -> Walker {
  Walker(() => self.next(graph))
}

///|
/// The remaining nodes of this DFS postorder over `graph`, as an iterator.
pub fn[G : @graph.NeighborSource] DfsPostOrder::iter(
  self : DfsPostOrder,
  graph : G,
) -> Iter[@graph.NodeId] {
  self.walker(graph).iter()
}

///|
/// Bind this `Topo` to `graph`, giving a `Walker`.
pub fn[G : @graph.NeighborSource] Topo::walker(
  self : Topo,
  graph : G,
) -> Walker {
  Walker(() => self.next(graph))
}

///|
/// The remaining nodes of this topological order over `graph`, as an iterator.
pub fn[G : @graph.NeighborSource] Topo::iter(
  self : Topo,
  graph : G,
) -> Iter[@graph.NodeId] {
  self.walker(graph).iter()
}
