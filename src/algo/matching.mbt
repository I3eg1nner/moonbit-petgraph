///|
/// A computed [*matching*](https://en.wikipedia.org/wiki/Matching_(graph_theory))
/// of a graph: a set of edges without common vertices.
///
/// Port of petgraph's `algo::matching::Matching`. `mates[i]` is the partner of
/// the node with index `i`, or `None` when that node is unmatched.
pub struct Matching[N, E] {
  graph : @graph.Graph[N, E]
  mates : Array[@graph.NodeId?]
  n_edges : Int
}

///|
/// Gets the matched counterpart of the given node, if there is any.
///
/// Returns `None` if the node is not matched or does not exist.
pub fn[N, E] Matching::mate(
  self : Matching[N, E],
  node : @graph.NodeId,
) -> @graph.NodeId? {
  let i = node.index()
  if i >= 0 && i < self.mates.length() {
    self.mates[i]
  } else {
    None
  }
}

///|
/// Iterates over all edges from the matching.
///
/// An edge is represented by its endpoints. The graph is considered undirected
/// and every pair of matched nodes is reported only once (from the endpoint
/// with the smaller index).
pub fn[N, E] Matching::edges(
  self : Matching[N, E],
) -> Iter[(@graph.NodeId, @graph.NodeId)] {
  let mut current = 0
  Iter::new(fn() {
    while current < self.mates.length() {
      let idx = current
      current = current + 1
      // Only report the edge from the lower-indexed endpoint, otherwise it
      // would be reported twice.
      if self.mates[idx] is Some(m) && m.index() > idx {
        return Some((@graph.NodeId::new(idx), m))
      }
    }
    None
  })
}

///|
/// Iterates over all nodes from the matching.
pub fn[N, E] Matching::nodes(self : Matching[N, E]) -> Iter[@graph.NodeId] {
  let mut current = 0
  Iter::new(fn() {
    while current < self.mates.length() {
      let idx = current
      current = current + 1
      if self.mates[idx] is Some(_) {
        return Some(@graph.NodeId::new(idx))
      }
    }
    None
  })
}

///|
/// Returns `true` if the given edge is in the matching, or `false` otherwise.
///
/// If any of the nodes does not exist, `false` is returned.
pub fn[N, E] Matching::contains_edge(
  self : Matching[N, E],
  a : @graph.NodeId,
  b : @graph.NodeId,
) -> Bool {
  self.mate(a) is Some(m) && m == b
}

///|
/// Returns `true` if the given node is in the matching, or `false` otherwise.
///
/// If the node does not exist, `false` is returned.
pub fn[N, E] Matching::contains_node(
  self : Matching[N, E],
  node : @graph.NodeId,
) -> Bool {
  self.mate(node) is Some(_)
}

///|
/// Gets the number of matched **edges**.
pub fn[N, E] Matching::len(self : Matching[N, E]) -> Int {
  self.n_edges
}

///|
/// Returns `true` if the number of matched **edges** is 0.
pub fn[N, E] Matching::is_empty(self : Matching[N, E]) -> Bool {
  self.n_edges == 0
}

///|
/// Returns `true` if the matching is
/// [*perfect*](https://en.wikipedia.org/wiki/Matching_(graph_theory)#Definitions),
/// i.e. every node in the graph is incident to an edge from the matching.
pub fn[N, E] Matching::is_perfect(self : Matching[N, E]) -> Bool {
  let n_nodes = self.graph.node_count()
  n_nodes % 2 == 0 && self.n_edges == n_nodes / 2
}

///|
/// The greedy matching used both as `greedy_matching`'s result and as the
/// initial matching of `maximum_matching`.
///
/// Port of petgraph's `greedy_matching_inner`: for every node, run a
/// non-backtracking DFS (each step follows the first not-yet-visited neighbor
/// and never backtracks) and alternate matched and unmatched edges along the
/// walk.
fn[N, E] greedy_matching_inner(
  g : @graph.Graph[N, E],
) -> (Array[@graph.NodeId?], Int) {
  let n = g.node_count()
  let mate : Array[@graph.NodeId?] = Array::make(n, None)
  let mut n_edges = 0
  let visited = @visit.VisitMap::new(n)
  for start in g.node_ids() {
    // `last` holds the pending endpoint of an unmatched edge, if any.
    let mut last : @graph.NodeId? = Some(start)
    let mut source = start
    while visited.visit(source) {
      // Follow the first unvisited neighbor; stop as soon as there is none.
      let mut step : @graph.NodeId? = None
      for target in g.neighbors(source) {
        if !visited.is_visited(target) {
          step = Some(target)
          break
        }
      }
      guard step is Some(next) else { break }
      match last {
        Some(pred) => {
          mate[pred.index()] = Some(next)
          mate[next.index()] = Some(pred)
          n_edges = n_edges + 1
          last = None
        }
        None => last = Some(next)
      }
      source = next
    }
  }
  (mate, n_edges)
}

///|
/// Compute a [*matching*](https://en.wikipedia.org/wiki/Matching_(graph_theory))
/// using a greedy heuristic.
///
/// The input graph is treated as if undirected. The underlying heuristic is
/// unspecified, but is guaranteed to be bounded by **O(|V| + |E|)**. No
/// guarantees about the output are given other than that it is a valid
/// matching. If you require a maximum matching, use `maximum_matching` instead.
///
/// Port of petgraph's `algo::greedy_matching`.
///
/// Time complexity: **O(|V| + |E|)**. Auxiliary space: **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges_undirected([
///     (0, 1),
///     (2, 3),
///   ])
///   let m = @algo.greedy_matching(g)
///   debug_inspect(m.len(), content="2")
///   debug_inspect(
///     m.contains_edge(@graph.NodeId::new(0), @graph.NodeId::new(1)),
///     content="true",
///   )
/// }
/// ```
pub fn[N, E] greedy_matching(g : @graph.Graph[N, E]) -> Matching[N, E] {
  let (mates, n_edges) = greedy_matching_inner(g)
  { graph: g, mates, n_edges }
}

///|
/// A vertex label used by Gabow's algorithm, the MoonBit port of petgraph's
/// `matching::Label`.
///
/// A vertex is *outer* iff it carries a label other than `LabelNone` and
/// `LabelFlag`.
priv enum Label {
  /// No label: the vertex is inner.
  LabelNone
  /// The start (free) vertex of the current search.
  LabelStart
  /// For an outer node `v`, `LabelVertex(w)` is another outer node on the path
  /// from `v` to the start vertex.
  LabelVertex(@graph.NodeId)
  /// For an outer node `v`, `LabelEdge(r, s)` records the two outer endpoints
  /// `r` and `s` of the blossom edge. petgraph also stores the edge id, but
  /// only ever pattern-matches it as `_`, so it is omitted here.
  LabelEdge(@graph.NodeId, @graph.NodeId)
  /// A temporary mark used while searching for the join vertex of two paths.
  LabelFlag(@graph.EdgeId)
}

///|
/// Whether the labeled vertex is an *outer* vertex.
fn Label::is_outer(self : Label) -> Bool {
  match self {
    LabelNone => false
    LabelFlag(_) => false
    _ => true
  }
}

///|
/// Whether the labeled vertex is an *inner* vertex (the complement of
/// `is_outer`).
fn Label::is_inner(self : Label) -> Bool {
  !self.is_outer()
}

///|
/// The vertex carried by a `LabelVertex` label, if this is one.
fn Label::to_vertex(self : Label) -> @graph.NodeId? {
  match self {
    LabelVertex(v) => Some(v)
    _ => None
  }
}

///|
/// Whether this label is the flag belonging to `edge`.
fn Label::is_flagged(self : Label, edge : @graph.EdgeId) -> Bool {
  match self {
    LabelFlag(flag) => flag == edge
    _ => false
  }
}

///|
/// Compute the [*maximum matching*](https://en.wikipedia.org/wiki/Matching_(graph_theory))
/// using [Gabow's algorithm](https://dl.acm.org/doi/10.1145/321941.321942).
///
/// The input graph is treated as if undirected. Blossoms (odd cycles) are
/// handled by labeling their inner vertices with the blossom edge, so this is a
/// true general-graph maximum matching, not a bipartite-only approximation.
///
/// Port of petgraph's `algo::maximum_matching`, including the greedy warm-start
/// and the dummy vertex Gabow numbers `0` (here the node bound, appended at the
/// end of the `mate` array).
///
/// Time complexity: **O(|V|³)**. Auxiliary space: **O(|V| + |E|)**.
///
/// # Example
/// ```mbt check
/// test {
///   //    +-- b ---- d ---- f
///   //   /    |      |
///   //  a     |      |
///   //   \    |      |
///   //    +-- c ---- e
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges_undirected([
///     (0, 1),
///     (0, 2),
///     (1, 2),
///     (1, 3),
///     (2, 4),
///     (3, 4),
///     (3, 5),
///   ])
///   let m = @algo.maximum_matching(g)
///   debug_inspect(m.len(), content="3")
///   debug_inspect(m.is_perfect(), content="true")
/// }
/// ```
pub fn[N, E] maximum_matching(g : @graph.Graph[N, E]) -> Matching[N, E] {
  let n = g.node_count()
  // A greedy matching is a fairly good initial matching; it speeds up the
  // computation by leaving less work to the complex algorithm.
  let (greedy, greedy_edges) = greedy_matching_inner(g)
  // Gabow's algorithm uses a dummy node at the end of the mate array.
  let dummy = n
  let mate : Array[@graph.NodeId?] = Array::make(n + 1, None)
  for i in 0..<n {
    mate[i] = greedy[i]
  }
  let mut n_edges = greedy_edges
  let label : Array[Label] = Array::make(n + 1, LabelNone)
  let first_inner : Array[Int] = Array::make(n + 1, -1)
  let visited = @visit.VisitMap::new(n)
  for start_ix in 0..<n {
    if mate[start_ix] is Some(_) {
      // The vertex is already matched; a start must be a free vertex.
      continue
    }
    // Begin a search from this node.
    label[start_ix] = LabelStart
    first_inner[start_ix] = dummy
    visited.reset()
    let start = @graph.NodeId::new(start_ix)
    if matching_search(g, start, mate, label, first_inner, visited, dummy) {
      n_edges = n_edges + 1
    }
    // Reset the labels: all vertices are inner for the next search.
    for i in 0..<label.length() {
      label[i] = LabelNone
    }
  }
  // Discard the dummy node.
  let mates : Array[@graph.NodeId?] = Array::makei(n, i => mate[i])
  { graph: g, mates, n_edges }
}

///|
/// One augmenting-path search of Gabow's algorithm, starting from the free
/// vertex `start`.
///
/// Returns `true` if an augmenting path was found and the matching augmented
/// (petgraph's `break 'search`, which MoonBit expresses as an early `return`).
fn[N, E] matching_search(
  g : @graph.Graph[N, E],
  start : @graph.NodeId,
  mate : Array[@graph.NodeId?],
  label : Array[Label],
  first_inner : Array[Int],
  visited : @visit.VisitMap,
  dummy : Int,
) -> Bool {
  // Queue of outer vertices that should be processed next; `head` is the
  // read cursor, making this a FIFO without an extra deque.
  let queue : Array[@graph.NodeId] = [start]
  visited.visit(start) |> ignore
  let mut head = 0
  while head < queue.length() {
    let outer_vertex = queue[head]
    head = head + 1
    for edge in g.edges_directed(outer_vertex, Outgoing) {
      guard g.edge_endpoints(edge) is Some((src, dst)) else { continue }
      if src == dst {
        // Ignore self-loops.
        continue
      }
      // petgraph's `edges()` reports the queried node as the source; the graph
      // here keeps the stored orientation, so normalize.
      let other_vertex = if src == outer_vertex { dst } else { src }
      let other_idx = other_vertex.index()
      if mate[other_idx] is None && other_vertex != start {
        // An augmenting path was found. If `other` were the start node, the
        // augmentation must not be performed, because the start vertex would
        // be incident to two edges, violating the matching property.
        mate[other_idx] = Some(outer_vertex)
        augment_path(outer_vertex, other_vertex, mate, label, dummy)
        return true
      } else if label[other_idx].is_outer() {
        // `other` is an outer vertex, so an odd cycle (blossom) was found.
        // Assign this edge as a label to all inner vertices in P(outer) and
        // P(other).
        find_join(
          edge,
          outer_vertex,
          other_vertex,
          mate,
          label,
          first_inner,
          dummy,
          labeled => if visited.visit(labeled) { queue.push(labeled) },
        )
      } else {
        let mate_vertex = mate[other_idx]
        let mate_idx = match mate_vertex {
          Some(id) => id.index()
          None => dummy
        }
        if label[mate_idx].is_inner() {
          // The mate of `other` has no label yet, but it actually is an outer
          // vertex: it lies on a path to the start that begins with a matched
          // edge. Record the label so its path can be reconstructed.
          label[mate_idx] = LabelVertex(outer_vertex)
          first_inner[mate_idx] = other_idx
        }
        // Enqueue only real vertices, and only on first discovery.
        if mate_vertex is Some(mv) && visited.visit(mv) {
          queue.push(mv)
        }
      }
    }
  }
  false
}

///|
/// Simultaneously traverse the inner vertices on paths P(source) and P(target)
/// to find their *join* — an inner vertex shared by both — and label every
/// inner vertex before the join with the blossom edge.
///
/// Port of petgraph's `find_join`. `visitor` is notified about each newly
/// labeled (now outer) vertex so the caller can enqueue it.
fn find_join(
  edge : @graph.EdgeId,
  edge_source : @graph.NodeId,
  edge_target : @graph.NodeId,
  mate : Array[@graph.NodeId?],
  label : Array[Label],
  first_inner : Array[Int],
  dummy : Int,
  visitor : (@graph.NodeId) -> Unit,
) -> Unit {
  let source = edge_source.index()
  let target = edge_target.index()
  let mut left = first_inner[source]
  let mut right = first_inner[target]
  if left == right {
    // No vertices can be labeled: both paths already refer to a common vertex,
    // which is the join.
    return
  }
  // Flag the (first) inner vertices, so they are assigned the join as their
  // first inner vertex.
  let flag = LabelFlag(edge)
  label[left] = flag
  label[right] = flag
  let join = for ;; {
    // Swap the sides, unless the right side is already finished.
    if right != dummy {
      let tmp = left
      left = right
      right = tmp
    }
    // Advance to the next inner vertex on P(source) or P(target). The
    // unwrapping is safe because `left` is never the dummy node here.
    guard! mate[left] is Some(left_mate)
    guard! label[left_mate.index()].to_vertex() is Some(next_inner)
    left = first_inner[next_inner.index()]
    if !label[left].is_flagged(edge) {
      label[left] = flag
    } else {
      // Already flagged, so the other side visited it first: it is the join.
      break left
    }
  }
  // Label all inner vertices on P(source) and P(target) with the found join.
  for endpoint in [source, target] {
    let mut inner = first_inner[endpoint]
    while inner != join {
      if inner != dummy {
        visitor(@graph.NodeId::new(inner))
      }
      label[inner] = LabelEdge(edge_source, edge_target)
      first_inner[inner] = join
      guard! mate[inner] is Some(inner_mate)
      guard! label[inner_mate.index()].to_vertex() is Some(next_inner)
      inner = first_inner[next_inner.index()]
    }
  }
  // All outer vertices on P(source) and P(target) up to the join now have the
  // join as their first inner vertex.
  for vertex_idx in 0..<label.length() {
    if vertex_idx != dummy &&
      label[vertex_idx].is_outer() &&
      first_inner[vertex_idx] >= 0 &&
      label[first_inner[vertex_idx]].is_outer() {
      first_inner[vertex_idx] = join
    }
  }
}

///|
/// Rematch the alternating path that ends at `outer`, so that `outer` becomes
/// matched to `other`.
///
/// Port of petgraph's `augment_path`. It recurses along vertex labels, and for
/// a blossom edge label it augments both directions around the blossom.
fn augment_path(
  outer : @graph.NodeId,
  other : @graph.NodeId,
  mate : Array[@graph.NodeId?],
  label : Array[Label],
  dummy : Int,
) -> Unit {
  let outer_idx = outer.index()
  let temp = mate[outer_idx]
  let temp_idx = match temp {
    Some(id) => id.index()
    None => dummy
  }
  mate[outer_idx] = Some(other)
  if mate[temp_idx] != Some(outer) {
    // We are at the end of the path, so it is completely rematched.
    return
  }
  match label[outer_idx] {
    LabelVertex(vertex) => {
      // The label refers to another outer vertex on the path, which becomes
      // the mate of the previous mate of the outer node.
      mate[temp_idx] = Some(vertex)
      if temp is Some(t) {
        augment_path(vertex, t, mate, label, dummy)
      }
    }
    // The label refers to an edge in a blossom, so both directions along the
    // blossom must be augmented.
    LabelEdge(source, target) => {
      augment_path(source, target, mate, label, dummy)
      augment_path(target, source, mate, label, dummy)
    }
    _ => abort("Unexpected label when augmenting path")
  }
}
