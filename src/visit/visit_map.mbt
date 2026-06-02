///|
/// A visited set for graph traversals.
///
/// Backed by a dense `Array[Bool]` indexed by `NodeId::index()`, sized to the
/// graph's node count. This mirrors petgraph's `FixedBitSet`-based visit map for
/// the `Graph` type: node ids are contiguous small integers, so a flat array is
/// both simple and fast.
pub struct VisitMap {
  visited : Array[Bool]
}

///|
/// Create a visit map large enough for `n` nodes, with nothing visited yet.
pub fn VisitMap::new(n : Int) -> VisitMap {
  { visited: Array::make(n, false) }
}

///|
/// Mark `a` as visited. Returns `true` if `a` was newly inserted (was not
/// previously visited), `false` if it had already been visited.
///
/// Out-of-range ids (beyond the current capacity) are grown into transparently
/// so the map stays robust if a graph reports a higher id than expected.
pub fn VisitMap::visit(self : VisitMap, a : @graph.NodeId) -> Bool {
  let i = a.index()
  while self.visited.length() <= i {
    self.visited.push(false)
  }
  if self.visited[i] {
    false
  } else {
    self.visited[i] = true
    true
  }
}

///|
/// Whether `a` has been visited.
pub fn VisitMap::is_visited(self : VisitMap, a : @graph.NodeId) -> Bool {
  let i = a.index()
  if i < self.visited.length() {
    self.visited[i]
  } else {
    false
  }
}

///|
/// Clear the visited state, keeping the same capacity.
pub fn VisitMap::reset(self : VisitMap) -> Unit {
  for i in 0..<self.visited.length() {
    self.visited[i] = false
  }
}
