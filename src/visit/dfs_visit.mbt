///|
/// A depth-first search (DFS) visitor event.
///
/// Each event carries the relevant node id(s). `Discover` and `Finish` also
/// carry a strictly increasing event "time" (an `Int`), matching petgraph's
/// `Time`.
pub enum DfsEvent {
  /// A node was discovered (first reached), at the given time.
  Discover(@graph.NodeId, Int)
  /// An edge of the tree formed by the traversal.
  TreeEdge(@graph.NodeId, @graph.NodeId)
  /// An edge to an already-discovered but not-yet-finished node (indicates a
  /// cycle in a directed graph).
  BackEdge(@graph.NodeId, @graph.NodeId)
  /// A cross or forward edge: an edge to an already-finished node.
  CrossForwardEdge(@graph.NodeId, @graph.NodeId)
  /// All edges from the node have been reported, at the given time.
  Finish(@graph.NodeId, Int)
} derive(Debug)

///|
/// Control flow for `depth_first_search` callbacks.
///
/// Deviation from petgraph: petgraph's `Control<B>` carries a value in
/// `Break(B)` and `depth_first_search` returns that `B`. Here `Break` carries
/// no value and `depth_first_search` returns `Unit`. The only downstream
/// consumer in this port (cycle detection) needs `Break` purely as an
/// early-exit signal, so the value channel is dropped to keep the API simple
/// and monomorphic. Callers that need to surface a result should capture it in
/// a closed-over `Ref` before returning `Break`.
pub(all) enum Control {
  /// Continue the DFS traversal as normal.
  Continue
  /// Prune the current node: stop reporting further edges out of it. A
  /// `Finish` event for the node is still reported.
  Prune
  /// Stop the whole traversal immediately.
  Break
} derive(Debug, Eq)

///|
/// A recursive depth-first search emitting discovery/finish events and edge
/// classifications.
///
/// Starting points are the nodes in `starts` (pass a single-element array to
/// start from one node). The traversal emits events for each reachable node and
/// edge; `visitor` is called for each event and its returned `Control` steers
/// the search:
///
/// - `Continue` resumes as normal.
/// - `Prune` (returned from any non-`Finish` event) stops traversing further
///   edges out of the current node and proceeds to its `Finish`.
/// - `Break` stops the entire traversal.
///
/// The classification is faithful enough to detect back edges (and therefore
/// cycles in directed graphs): an edge `(u, v)` to a discovered-but-unfinished
/// `v` is reported as `BackEdge`.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 -> 1 -> 2 -> 0 forms a cycle; the edge 2 -> 0 is a back edge.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2), (2, 0)])
///   let back_edges = []
///   @visit.depth_first_search(g, [@graph.NodeId::new(0)], event => {
///     if event is BackEdge(u, v) {
///       back_edges.push((u.index(), v.index()))
///     }
///     Continue
///   })
///   // The cycle surfaces as exactly one back edge: 2 -> 0.
///   debug_inspect(back_edges, content="[(2, 0)]")
/// }
/// ```
pub fn[G : @graph.NeighborSource] depth_first_search(
  graph : G,
  starts : Array[@graph.NodeId],
  visitor : (DfsEvent) -> Control,
) -> Unit {
  let n = graph.node_count()
  let discovered = VisitMap::new(n)
  let finished = VisitMap::new(n)
  let time = Ref(0)
  for start in starts {
    if dfs_visitor(graph, start, visitor, discovered, finished, time) is Break {
      return
    }
  }
}

///|
/// Post-increment the time counter, returning the value before the increment.
fn time_post_inc(time : Ref[Int]) -> Int {
  let v = time.val
  time.val = v + 1
  v
}

///|
/// Recursive worker for `depth_first_search`. Returns `Break` if the whole
/// traversal should stop, otherwise `Continue`.
fn[G : @graph.NeighborSource] dfs_visitor(
  graph : G,
  u : @graph.NodeId,
  visitor : (DfsEvent) -> Control,
  discovered : VisitMap,
  finished : VisitMap,
  time : Ref[Int],
) -> Control {
  if !discovered.visit(u) {
    return Continue
  }
  match visitor(Discover(u, time_post_inc(time))) {
    Break => return Break
    // Pruning on `Discover` skips this node's edges, jumping straight to Finish.
    Prune => ()
    Continue =>
      for v in graph.neighbors_directed(u, Outgoing) {
        if !discovered.is_visited(v) {
          match visitor(TreeEdge(u, v)) {
            Break => return Break
            // Prune on a tree edge: skip recursing into `v`, continue with the
            // next edge.
            Prune => continue
            Continue =>
              if dfs_visitor(graph, v, visitor, discovered, finished, time)
                is Break {
                return Break
              }
          }
        } else if !finished.is_visited(v) {
          match visitor(BackEdge(u, v)) {
            Break => return Break
            Prune | Continue => ()
          }
        } else {
          match visitor(CrossForwardEdge(u, v)) {
            Break => return Break
            Prune | Continue => ()
          }
        }
      }
  }
  finished.visit(u) |> ignore
  match visitor(Finish(u, time_post_inc(time))) {
    Break => Break
    // Pruning on `Finish` is unsupported in petgraph (it panics); here we treat
    // it as a no-op and continue, since `Finish` is the last event for `u`.
    Prune | Continue => Continue
  }
}
