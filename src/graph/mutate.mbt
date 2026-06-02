///|
/// The two directions, in `[Outgoing, Incoming]` order, matching petgraph's
/// `DIRECTIONS` constant.
let directions : Array[Direction] = [Outgoing, Incoming]

///|
/// `Vec::swap_remove` for the node array: swap element `i` with the last,
/// then remove and return it. The element previously at the last index ends up
/// at `i`. Panics if `i` is out of bounds.
fn[N, E] Graph::swap_remove_node(self : Graph[N, E], i : Int) -> Node[N] {
  let last = self.nodes.length() - 1
  if i != last {
    self.nodes.swap(i, last)
  }
  self.nodes.pop().unwrap()
}

///|
/// `Vec::swap_remove` for the edge array (see `swap_remove_node`).
fn[N, E] Graph::swap_remove_edge(self : Graph[N, E], i : Int) -> Edge[E] {
  let last = self.edges.length() - 1
  if i != last {
    self.edges.swap(i, last)
  }
  self.edges.pop().unwrap()
}

///|
/// Add a node with associated `weight`, returning its identifier. O(1).
pub fn[N, E] Graph::add_node(self : Graph[N, E], weight : N) -> NodeId {
  let node_idx = NodeId::new(self.nodes.length())
  self.nodes.push({ weight, next_out: EdgeId::end(), next_in: EdgeId::end() })
  node_idx
}

///|
/// Set the weight of node `a`. Does nothing if `a` is out of bounds.
///
/// MoonBit replacement for petgraph's `node_weight_mut` (no `&mut` references).
pub fn[N, E] Graph::set_node_weight(
  self : Graph[N, E],
  a : NodeId,
  weight : N,
) -> Unit {
  if self.nodes.get(a.index()) is Some(node) {
    node.weight = weight
  }
}

///|
/// Add an edge from `a` to `b` with associated `weight`, returning its
/// identifier. O(1).
///
/// Parallel (duplicate) edges are allowed; use `update_edge` to avoid them.
/// Self-loops (`a == b`) are handled like petgraph's `Pair::One`: the single
/// node slot's two heads are both updated.
///
/// Panics if either endpoint is out of bounds.
pub fn[N, E] Graph::add_edge(
  self : Graph[N, E],
  a : NodeId,
  b : NodeId,
  weight : E,
) -> EdgeId {
  let edge_idx = EdgeId::new(self.edges.length())
  guard self.nodes.get(a.index()) is Some(an) else {
    abort("Graph::add_edge: node indices out of bounds")
  }
  guard self.nodes.get(b.index()) is Some(bn) else {
    abort("Graph::add_edge: node indices out of bounds")
  }
  let edge : Edge[E] = {
    weight,
    src: a,
    dst: b,
    next_out: EdgeId::end(),
    next_in: EdgeId::end(),
  }
  if a == b {
    // self-loop: petgraph's Pair::One -- read both heads, then write both.
    edge.next_out = an.next_out
    edge.next_in = an.next_in
    an.next_out = edge_idx
    an.next_in = edge_idx
  } else {
    // a and b are different nodes.
    edge.next_out = an.next_out
    edge.next_in = bn.next_in
    an.next_out = edge_idx
    bn.next_in = edge_idx
  }
  self.edges.push(edge)
  edge_idx
}

///|
/// Add or update an edge from `a` to `b`. If an edge already exists its weight
/// is updated; otherwise a new edge is added. Returns the affected edge's id.
///
/// O(e') where e' is the number of edges connected to `a` (and `b` if
/// undirected).
pub fn[N, E] Graph::update_edge(
  self : Graph[N, E],
  a : NodeId,
  b : NodeId,
  weight : E,
) -> EdgeId {
  if self.find_edge(a, b) is Some(ix) {
    if self.edges.get(ix.index()) is Some(ed) {
      ed.weight = weight
      return ix
    }
  }
  self.add_edge(a, b, weight)
}

///|
/// For edge `e` with endpoints `edge_node`, replace links pointing to `e` with
/// links to `edge_next` (per direction). Literal port of petgraph's
/// `change_edge_links`.
fn[N, E] Graph::change_edge_links(
  self : Graph[N, E],
  edge_node : (NodeId, NodeId),
  e : EdgeId,
  edge_next : (EdgeId, EdgeId),
) -> Unit {
  for d in directions {
    let endpoint = match d {
      Outgoing => edge_node.0
      Incoming => edge_node.1
    }
    let next_link = match d {
      Outgoing => edge_next.0
      Incoming => edge_next.1
    }
    guard self.nodes.get(endpoint.index()) is Some(node) else {
      // Edge's endpoint not found; in petgraph this is a debug_assert(false).
      continue
    }
    let fst = node.next(d)
    if fst == e {
      node.set_next(d, next_link)
    } else {
      // Walk the adjacency list in direction d, find the edge whose `next`
      // pointer is `e`, and splice it out.
      let mut cur = fst
      while self.edges.get(cur.index()) is Some(curedge) {
        if curedge.next(d) == e {
          curedge.set_next(d, next_link)
          break // an edge can only be present once in the list
        }
        cur = curedge.next(d)
      }
    }
  }
}

///|
/// Remove edge `e` and return its weight, or `None` if it didn't exist.
///
/// Apart from `e`, this invalidates the last edge id (it is swapped into `e`'s
/// slot). O(e') over the four affected edge lists.
pub fn[N, E] Graph::remove_edge(self : Graph[N, E], e : EdgeId) -> E? {
  guard self.edges.get(e.index()) is Some(ed) else { return None }
  let edge_node = (ed.src, ed.dst)
  let edge_next = (ed.next_out, ed.next_in)
  // Unlink `e` from both the outgoing and incoming lists.
  self.change_edge_links(edge_node, e, edge_next)
  self.remove_edge_adjust_indices(e)
}

///|
/// swap_remove edge `e` from the edge array and fix up the one edge (if any)
/// that was swapped into `e`'s slot. Literal port of
/// `remove_edge_adjust_indices`.
fn[N, E] Graph::remove_edge_adjust_indices(
  self : Graph[N, E],
  e : EdgeId,
) -> E? {
  let edge = self.swap_remove_edge(e.index())
  // If nothing was swapped into place (we removed the last edge), we are done.
  guard self.edges.get(e.index()) is Some(swapped) else {
    return Some(edge.weight)
  }
  let swap = (swapped.src, swapped.dst)
  let swapped_e = EdgeId::new(self.edges.length())
  // Redirect links that pointed at the old last index to the new index `e`.
  self.change_edge_links(swap, swapped_e, (e, e))
  Some(edge.weight)
}

///|
/// Remove node `a` and return its weight, or `None` if it didn't exist.
///
/// Removes all incident edges first, then swap_removes the node and fixes the
/// endpoints of the displaced node's edges. Literal port of petgraph's
/// `remove_node`.
pub fn[N, E] Graph::remove_node(self : Graph[N, E], a : NodeId) -> N? {
  guard self.nodes.get(a.index()) is Some(_) else { return None }
  // Remove all edges incident to `a` (both outgoing and incoming).
  for d in directions {
    while true {
      let next = self.nodes[a.index()].next(d)
      if next.is_end() {
        break
      }
      let _ = self.remove_edge(next)
    }
  }
  // swap_remove the node; only the swapped-in node changes its id, so we only
  // have to walk its edges and rewrite their endpoint references.
  let node = self.swap_remove_node(a.index())
  guard self.nodes.get(a.index()) is Some(swapped) else {
    // Nothing relocated (we removed the last node).
    return Some(node.weight)
  }
  let swap_edges = (swapped.next_out, swapped.next_in)
  let old_index = NodeId::new(self.nodes.length())
  let new_index = a
  // For out edges adjust their source; for in edges adjust their target.
  for d in directions {
    let mut cur = match d {
      Outgoing => swap_edges.0
      Incoming => swap_edges.1
    }
    while self.edges.get(cur.index()) is Some(curedge) {
      // The endpoint in direction d should currently be the old index.
      if curedge.node(d) == old_index {
        curedge.set_node(d, new_index)
      }
      cur = curedge.next(d)
    }
  }
  Some(node.weight)
}

///|
/// Reverse the direction of all edges. Swaps each edge's endpoints and link
/// pairs, and each node's link pair.
pub fn[N, E] Graph::reverse(self : Graph[N, E]) -> Unit {
  for edge in self.edges {
    let s = edge.src
    edge.src = edge.dst
    edge.dst = s
    let no = edge.next_out
    edge.next_out = edge.next_in
    edge.next_in = no
  }
  for node in self.nodes {
    let no = node.next_out
    node.next_out = node.next_in
    node.next_in = no
  }
}

///|
/// Remove all nodes and edges.
pub fn[N, E] Graph::clear(self : Graph[N, E]) -> Unit {
  self.nodes.clear()
  self.edges.clear()
}

///|
/// Remove all edges, keeping nodes (and resetting their adjacency heads).
pub fn[N, E] Graph::clear_edges(self : Graph[N, E]) -> Unit {
  self.edges.clear()
  for node in self.nodes {
    node.next_out = EdgeId::end()
    node.next_in = EdgeId::end()
  }
}
