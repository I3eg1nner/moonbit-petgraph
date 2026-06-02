///|
/// The graph's node type.
///
/// `next_out` / `next_in` are the heads of the intrusive outgoing and incoming
/// edge linked lists, mirroring petgraph's `next: [EdgeIndex; 2]`.
struct Node[N] {
  mut weight : N
  mut next_out : EdgeId
  mut next_in : EdgeId
}

///|
/// The first edge in the given direction (the head of that adjacency list).
fn[N] Node::next(self : Node[N], dir : Direction) -> EdgeId {
  match dir {
    Outgoing => self.next_out
    Incoming => self.next_in
  }
}

///|
/// Set the first edge in the given direction.
fn[N] Node::set_next(self : Node[N], dir : Direction, e : EdgeId) -> Unit {
  match dir {
    Outgoing => self.next_out = e
    Incoming => self.next_in = e
  }
}

///|
/// The graph's edge type.
///
/// `next_out` / `next_in` are the next links in the source's outgoing and the
/// target's incoming edge lists, mirroring petgraph's `next: [EdgeIndex; 2]`.
/// `src` / `dst` mirror petgraph's `node: [NodeIndex; 2]` (source, target).
struct Edge[E] {
  mut weight : E
  mut next_out : EdgeId
  mut next_in : EdgeId
  mut src : NodeId
  mut dst : NodeId
}

///|
/// The next edge for the given direction.
fn[E] Edge::next(self : Edge[E], dir : Direction) -> EdgeId {
  match dir {
    Outgoing => self.next_out
    Incoming => self.next_in
  }
}

///|
/// Set the next edge for the given direction.
fn[E] Edge::set_next(self : Edge[E], dir : Direction, e : EdgeId) -> Unit {
  match dir {
    Outgoing => self.next_out = e
    Incoming => self.next_in = e
  }
}

///|
/// The endpoint node in the given direction.
///
/// `node(Outgoing)` is the source, `node(Incoming)` is the target. This mirrors
/// petgraph's `edge.node[dir.index()]` so `change_edge_links` ports literally.
fn[E] Edge::node(self : Edge[E], dir : Direction) -> NodeId {
  match dir {
    Outgoing => self.src
    Incoming => self.dst
  }
}

///|
/// Set the endpoint node in the given direction.
fn[E] Edge::set_node(self : Edge[E], dir : Direction, n : NodeId) -> Unit {
  match dir {
    Outgoing => self.src = n
    Incoming => self.dst = n
  }
}

///|
/// `Graph[N, E]` is an adjacency-list graph data structure.
///
/// It is a MoonBit port of petgraph's core `Graph`, dropping the `Ix` (index
/// type) and `Ty` (edge type) type parameters: the index type is always `Int`,
/// and directedness is the runtime `ty` field instead of a trait.
///
/// - `N` and `E` are the node and edge weight types.
/// - Node and edge identifiers range over a compact interval `0 .. count-1`.
/// - Removing a node or edge may shift the last node/edge into the freed slot
///   (`swap_remove` semantics), so identifiers are only stable across additions.
pub struct Graph[N, E] {
  nodes : Array[Node[N]]
  edges : Array[Edge[E]]
  ty : Directedness
}

///|
/// Create a new `Graph` with directed edges.
pub fn[N, E] Graph::new() -> Graph[N, E] {
  { nodes: [], edges: [], ty: Directed }
}

///|
/// Create a new `Graph` with undirected edges.
pub fn[N, E] Graph::new_undirected() -> Graph[N, E] {
  { nodes: [], edges: [], ty: Undirected }
}

///|
/// Create a new directed `Graph` with capacity hints for nodes and edges.
///
/// The capacity arguments are accepted for API parity with petgraph; MoonBit
/// `Array`s grow automatically, so they are advisory only.
pub fn[N, E] Graph::with_capacity(_nodes : Int, _edges : Int) -> Graph[N, E] {
  { nodes: [], edges: [], ty: Directed }
}

///|
/// Whether the graph has directed edges.
pub fn[N, E] Graph::is_directed(self : Graph[N, E]) -> Bool {
  self.ty == Directed
}

///|
/// The number of nodes (vertices) in the graph. O(1).
pub fn[N, E] Graph::node_count(self : Graph[N, E]) -> Int {
  self.nodes.length()
}

///|
/// The number of edges in the graph. O(1).
pub fn[N, E] Graph::edge_count(self : Graph[N, E]) -> Int {
  self.edges.length()
}
