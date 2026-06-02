///|
/// The sentinel value used to denote an absent node or edge index.
///
/// This mirrors petgraph's `IndexType::max()` for the default `u32` index type
/// reinterpreted as a value; here the index type is `Int`, so the largest
/// positive `Int` is used as the "end" marker.
pub const END : Int = 2147483647

///|
/// Node identifier.
///
/// A thin newtype wrapper around `Int` (not a type alias), so that node and
/// edge identifiers are not accidentally interchangeable.
pub struct NodeId(Int) derive(Eq, Hash, Compare, Debug)

///|
/// Construct a `NodeId` from a raw integer index.
pub fn NodeId::new(x : Int) -> NodeId {
  NodeId(x)
}

///|
/// Return the raw integer index of a `NodeId`.
pub fn NodeId::index(self : NodeId) -> Int {
  self.0
}

///|
/// The sentinel `NodeId` used to mark absence (end of an adjacency list).
pub fn NodeId::end() -> NodeId {
  NodeId(END)
}

///|
/// Whether this `NodeId` is the `end` sentinel.
pub fn NodeId::is_end(self : NodeId) -> Bool {
  self.0 == END
}

///|
/// Edge identifier.
///
/// A thin newtype wrapper around `Int` (not a type alias).
pub struct EdgeId(Int) derive(Eq, Hash, Compare, Debug)

///|
/// Construct an `EdgeId` from a raw integer index.
pub fn EdgeId::new(x : Int) -> EdgeId {
  EdgeId(x)
}

///|
/// Return the raw integer index of an `EdgeId`.
pub fn EdgeId::index(self : EdgeId) -> Int {
  self.0
}

///|
/// The sentinel `EdgeId` used to mark absence / terminate an adjacency list.
pub fn EdgeId::end() -> EdgeId {
  EdgeId(END)
}

///|
/// Whether this `EdgeId` is the `end` sentinel.
pub fn EdgeId::is_end(self : EdgeId) -> Bool {
  self.0 == END
}

///|
/// Edge direction.
///
/// `Outgoing` is an outward edge *from* the current node; `Incoming` is an
/// inbound edge *to* the current node.
pub(all) enum Direction {
  Outgoing
  Incoming
} derive(Eq, Debug)

///|
/// Return `0` for `Outgoing` and `1` for `Incoming`.
///
/// These indices are used to address the two-element `next` link arrays
/// (`[out, in]`) on nodes and edges.
pub fn Direction::index(self : Direction) -> Int {
  match self {
    Outgoing => 0
    Incoming => 1
  }
}

///|
/// Return the opposite `Direction`.
pub fn Direction::opposite(self : Direction) -> Direction {
  match self {
    Outgoing => Incoming
    Incoming => Outgoing
  }
}

///|
/// Whether the graph's edges are directed or undirected.
///
/// In petgraph this is a type parameter (`Ty`); here it is a runtime enum field
/// on the graph.
pub(all) enum Directedness {
  Directed
  Undirected
} derive(Eq, Debug)
