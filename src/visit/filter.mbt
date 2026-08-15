///|
/// A node-filtering graph adaptor.
///
/// `NodeFiltered` presents a subgraph of `graph`: only the nodes for which
/// `include_node` returns `true` are part of the view. Filtered-out nodes
/// disappear from `node_ids` and from every neighbor list, and a filtered-out
/// node has no neighbors at all (petgraph's `include_source` flag).
///
/// Deviation from petgraph: `node_count` reports the *underlying* graph's node
/// count, not the number of kept nodes. petgraph does the same thing in spirit
/// (it delegates `NodeIndexable`/`Visitable` to the inner graph and does not
/// implement `NodeCount` for `NodeFiltered` at all): the count is used by the
/// traversals only to size a `VisitMap` indexed by the *underlying* node
/// indices, so it must stay the inner count for the visit maps to be valid.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 -> 1 -> 2 with node 1 filtered out: 2 is no longer reachable from 0.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
///   let f = @visit.NodeFiltered::from_fn(g, n => n.index() != 1)
///   let dfs = @visit.Dfs::new(f, @graph.NodeId::new(0))
///   let order = []
///   while dfs.next(f) is Some(n) {
///     order.push(n.index())
///   }
///   debug_inspect(order, content="[0]")
/// }
/// ```
pub struct NodeFiltered[G] {
  /// The underlying graph.
  graph : G
  /// The node predicate: return `true` to keep the node in the view.
  include_node : (@graph.NodeId) -> Bool
}

///|
/// Create a `NodeFiltered` adaptor from the closure `filter`, mirroring
/// petgraph's `NodeFiltered::from_fn`.
pub fn[G] NodeFiltered::from_fn(
  graph : G,
  filter : (@graph.NodeId) -> Bool,
) -> NodeFiltered[G] {
  { graph, include_node: filter }
}

///|
/// The underlying graph's node count; see the type-level note on why the kept
/// nodes are *not* counted here.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for NodeFiltered[G] with fn node_count(
  self,
) {
  self.graph.node_count()
}

///|
/// Only the nodes accepted by the predicate, in the underlying order.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for NodeFiltered[G] with fn node_ids(
  self,
) {
  let keep = self.include_node
  self.graph.node_ids().filter(n => keep(n))
}

///|
/// Neighbors of `a` restricted to the kept nodes. A filtered-out `a` has no
/// neighbors at all, so the subgraph has no edges touching removed nodes.
pub impl[G : @graph.NeighborSource] @graph.NeighborSource for NodeFiltered[G] with fn neighbors_directed(
  self,
  a,
  dir,
) {
  let keep = self.include_node
  if !keep(a) {
    Iter::empty()
  } else {
    self.graph.neighbors_directed(a, dir).filter(n => keep(n))
  }
}

///|
/// An edge-filtering graph adaptor.
///
/// `EdgeFiltered` presents a graph with the same nodes as `graph` but only the
/// edges for which `include_edge` returns `true`. The predicate receives the
/// edge id together with its source and target, so it can select on edge
/// identity, endpoints, or — by capturing the graph in the closure and calling
/// `edge_weight` — the edge weight.
///
/// Unlike the other adaptors this one is concrete over `@graph.Graph[N, E]`
/// rather than generic over `@graph.NeighborSource`: filtering edges needs edge
/// *identity*, which `NeighborSource` (a node-only view) cannot express.
///
/// Deviation from petgraph: petgraph's filter takes a full `EdgeRef` (id,
/// source, target and a reference to the weight). This port passes id, source
/// and target; the weight is reachable through the captured graph.
///
/// # Example
/// ```mbt check
/// test {
///   // Drop the edge 1 -> 2, cutting 2 off from 0.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
///   let f = @visit.EdgeFiltered::from_fn(g, (_, src, dst) => {
///     !(src.index() == 1 && dst.index() == 2)
///   })
///   let dfs = @visit.Dfs::new(f, @graph.NodeId::new(0))
///   let order = []
///   while dfs.next(f) is Some(n) {
///     order.push(n.index())
///   }
///   debug_inspect(order, content="[0, 1]")
/// }
/// ```
pub struct EdgeFiltered[N, E] {
  /// The underlying graph.
  graph : @graph.Graph[N, E]
  /// The edge predicate, taking the edge id, its source and its target;
  /// return `true` to keep the edge in the view.
  include_edge : (@graph.EdgeId, @graph.NodeId, @graph.NodeId) -> Bool
}

///|
/// Create an `EdgeFiltered` adaptor from the closure `filter`, mirroring
/// petgraph's `EdgeFiltered::from_fn`.
pub fn[N, E] EdgeFiltered::from_fn(
  graph : @graph.Graph[N, E],
  filter : (@graph.EdgeId, @graph.NodeId, @graph.NodeId) -> Bool,
) -> EdgeFiltered[N, E] {
  { graph, include_edge: filter }
}

///|
/// Filtering edges does not change the node set.
pub impl[N, E] @graph.NeighborSource for EdgeFiltered[N, E] with fn node_count(
  self,
) {
  self.graph.node_count()
}

///|
/// Filtering edges does not change the node set.
pub impl[N, E] @graph.NeighborSource for EdgeFiltered[N, E] with fn node_ids(
  self,
) {
  self.graph.node_ids()
}

///|
/// Walk the edges of `a` in direction `dir`, keep the ones the predicate
/// accepts, and yield the endpoint at the far side of each. Following petgraph,
/// the far side is the source when the source is not `a` (the `Incoming` case),
/// and the target otherwise (which also covers self-loops).
pub impl[N, E] @graph.NeighborSource for EdgeFiltered[N, E] with fn neighbors_directed(
  self,
  a,
  dir,
) {
  let keep = self.include_edge
  let graph = self.graph
  graph
  .edges_directed(a, dir)
  .filter_map(e => {
    match graph.edge_endpoints(e) {
      None => None
      Some((src, dst)) =>
        if keep(e, src, dst) {
          if src != a {
            Some(src)
          } else {
            Some(dst)
          }
        } else {
          None
        }
    }
  })
}
