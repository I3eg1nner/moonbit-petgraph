///|
/// `Measure` is the trait used by the path-finding algorithms in this package
/// (`dijkstra`, `astar`, `bellman_ford`, `min_spanning_tree`) to describe an
/// edge-weight / accumulated-distance type.
///
/// It is the MoonBit counterpart of petgraph's `Measure` bound
/// (`PartialOrd + Add<Self> + Default`):
///
/// * `zero()` is the additive identity (petgraph's `Default::default()`), used
///   as the distance of the source node to itself.
/// * `add(self, other)` accumulates two weights along a path.
/// * `compare(self, other)` is a total order returning `< 0`, `0` or `> 0`.
///
/// `Int` and `Double` both implement `Measure`, so both can be used directly as
/// edge weights. Weights are expected to be non-negative for `dijkstra`,
/// `astar` and `min_spanning_tree`; `bellman_ford` tolerates negative weights.
pub trait Measure {
  fn zero() -> Self
  fn add(Self, Self) -> Self
  fn compare(Self, Self) -> Int
}

///|
pub impl Measure for Int with fn zero() {
  0
}

///|
pub impl Measure for Int with fn add(self, other) {
  self + other
}

///|
pub impl Measure for Int with fn compare(self, other) {
  self.compare(other)
}

///|
pub impl Measure for Double with fn zero() {
  0.0
}

///|
pub impl Measure for Double with fn add(self, other) {
  self + other
}

///|
pub impl Measure for Double with fn compare(self, other) {
  self.compare(other)
}
