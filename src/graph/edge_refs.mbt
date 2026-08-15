///|
/// A reference to a `Graph` edge: its identifier, its endpoints and its weight.
///
/// This is the MoonBit port of petgraph's `EdgeReference`. Rust stores a borrow
/// of the weight (`&'a E`); MoonBit has no lifetimes, so the weight is captured
/// by value when the reference is produced. Mutating the graph afterwards is
/// therefore not observable through an already-produced `EdgeRef`.
///
/// The `source` / `target` pair is *not* always `(edge.src, edge.dst)`: for an
/// undirected graph the pair is oriented so that the node you asked about is
/// the `source` (see `Graph::edges`), exactly like petgraph's `swap_pair`.
pub struct EdgeRef[E] {
  id : EdgeId
  source : NodeId
  target : NodeId
  weight : E
} derive(Debug)

///|
/// Create an iterator over all edges of the graph, in index order
/// (`0 .. edge_count-1`).
///
/// The endpoints are reported unswapped (`source` is the edge's stored source),
/// matching petgraph's `EdgeReferences`. Returns a fresh, lazy single-use
/// `Iter[EdgeRef[E]]`.
pub fn[N, E] Graph::edge_references(self : Graph[N, E]) -> Iter[EdgeRef[E]] {
  let mut i = 0
  Iter::new(fn() {
    if self.edges.get(i) is Some(edge) {
      let cur = i
      i = i + 1
      Some({
        id: EdgeId::new(cur),
        source: edge.src,
        target: edge.dst,
        weight: edge.weight,
      })
    } else {
      None
    }
  })
}

///|
/// All edges of `a`.
///
/// - `Directed`: outgoing edges from `a`.
/// - `Undirected`: all edges connected to `a`.
///
/// Produces an empty iterator if the node doesn't exist. Equivalent to
/// petgraph's `edges(a)` == `edges_directed(a, Outgoing)`; every yielded
/// `EdgeRef` has `source == a` (for the undirected case the stored endpoints
/// are swapped when needed to make that true).
///
/// For a directed graph edges are listed in reverse order of their addition.
/// For an undirected graph the outgoing list comes first, then the incoming
/// list, each in reverse insertion order; self-loops are yielded once.
pub fn[N, E] Graph::edges(self : Graph[N, E], a : NodeId) -> Iter[EdgeRef[E]] {
  self.walk_edge_refs(a, Outgoing)
}

///|
/// Shared walk behind `edges`, a literal port of petgraph's `Edges::next`:
///
/// ```text
///     type        direction    |    iterate over    reverse
///   Directed      Outgoing     |      outgoing        no
///   Directed      Incoming     |      incoming        no
///  Undirected     Outgoing     |        both       incoming
///  Undirected     Incoming     |        both       outgoing
/// ```
///
/// `iterate_over` is `None` for "both"; `reverse` is `None` for "no". The
/// reversed list has its endpoint pair swapped so the queried node stays on the
/// requested side.
fn[N, E] Graph::walk_edge_refs(
  self : Graph[N, E],
  a : NodeId,
  dir : Direction,
) -> Iter[EdgeRef[E]] {
  let (out0, in0) = match self.nodes.get(a.index()) {
    None => (EdgeId::end(), EdgeId::end())
    Some(n) => (n.next_out, n.next_in)
  }
  let directed = self.is_directed()
  let iterate_over : Direction? = if directed { Some(dir) } else { None }
  let reverse : Direction? = if directed { None } else { Some(dir.opposite()) }
  let do_out = match iterate_over {
    Some(d) => d == Outgoing
    None => true
  }
  let do_in = match iterate_over {
    Some(d) => d == Incoming
    None => true
  }
  let both = iterate_over is None
  let mut o = if do_out { out0 } else { EdgeId::end() }
  let mut i = if do_in { in0 } else { EdgeId::end() }
  Iter::new(fn() {
    // Outgoing list.
    if self.edges.get(o.index()) is Some(edge) {
      let cur = o
      o = edge.next_out
      let (s, t) = if reverse is Some(Outgoing) {
        (edge.dst, edge.src)
      } else {
        (edge.src, edge.dst)
      }
      return Some({ id: cur, source: s, target: t, weight: edge.weight })
    }
    // Incoming list. In any of the "both" situations a self-loop would be
    // yielded twice, so skip it here.
    while self.edges.get(i.index()) is Some(edge) {
      let cur = i
      i = edge.next_in
      if both && edge.src == a {
        continue
      }
      let (s, t) = if reverse is Some(Incoming) {
        (edge.dst, edge.src)
      } else {
        (edge.src, edge.dst)
      }
      return Some({ id: cur, source: s, target: t, weight: edge.weight })
    }
    None
  })
}

///|
/// All edges connecting `a` to `b`.
///
/// - `Directed`: outgoing edges from `a` whose target is `b`.
/// - `Undirected`: all edges between `a` and `b`, in either stored orientation.
///
/// The edges from `a` to `b` are listed first, then (undirected only) the edges
/// stored as `b -> a`; within each group the most recently added edge comes
/// first. Adapted from petgraph's `EdgesConnecting`, which yields
/// `EdgeReference`s: here the ids are returned directly.
pub fn[N, E] Graph::edges_connecting(
  self : Graph[N, E],
  a : NodeId,
  b : NodeId,
) -> Iter[EdgeId] {
  self.edges(a).filter(r => r.target == b).map(r => r.id)
}
