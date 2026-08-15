///|
/// A minimal read-only view of a graph as a neighbor source.
///
/// This light trait is consumed by other packages (algorithms, traversals) so
/// they can operate over any graph-like type that can enumerate its nodes and
/// each node's neighbors in a given direction. `NodeId` and `Direction` are
/// defined in this package so the trait can be implemented for foreign graph
/// types too.
///
/// The trait is `pub(open)` so that adaptor types living in other packages
/// (`@visit.Reversed`, `@visit.NodeFiltered`, ...) can implement it and compose
/// with every traversal that is generic over a `NeighborSource`.
pub(open) trait NeighborSource {
  fn node_count(Self) -> Int
  fn node_ids(Self) -> Iter[NodeId]
  fn neighbors_directed(Self, NodeId, Direction) -> Iter[NodeId]
}

///|
pub impl[N, E] NeighborSource for Graph[N, E] with fn node_count(self) {
  self.node_count()
}

///|
pub impl[N, E] NeighborSource for Graph[N, E] with fn node_ids(self) {
  self.node_ids()
}

///|
pub impl[N, E] NeighborSource for Graph[N, E] with fn neighbors_directed(
  self,
  a,
  dir,
) {
  self.neighbors_directed(a, dir)
}
