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

///|
/// `BoundedMeasure` extends `Measure` with the operations needed by algorithms
/// that must represent "unreachable" as a concrete saturating value, detect
/// overflow when relaxing through it, or undo an addition.
///
/// It merges petgraph's `BoundedMeasure` (`max`, `overflowing_add`) and the
/// subtraction half of its `PositiveMeasure` / `Sub` bounds into one trait, so
/// `floyd_warshall`, `johnson`, the max-flow algorithms and `steiner_tree` can
/// all share a single numeric bound.
///
/// * `max_value()` is the saturating "infinity" sentinel used for unreachable
///   pairs. For `Int` it is `2147483647`; for `Double` it is `+inf`.
/// * `checked_add(a, b)` is `Some(a + b)` unless the sum overflows, in which
///   case it is `None`. `Double` never reports overflow: it saturates at `+inf`.
/// * `sub(a, b)` is `a - b`, used for potential-based edge reweighting and for
///   decrementing residual capacities.
pub trait BoundedMeasure: Measure {
  fn max_value() -> Self
  fn checked_add(Self, Self) -> Self?
  fn sub(Self, Self) -> Self
}

///|
pub impl BoundedMeasure for Int with fn max_value() {
  2147483647
}

///|
/// Detects overflow by checking the sign of the result against the signs of the
/// operands: two same-signed operands whose sum flips sign have overflowed.
pub impl BoundedMeasure for Int with fn checked_add(self, other) {
  let sum = self + other
  if (self >= 0) == (other >= 0) && (sum >= 0) != (self >= 0) {
    None
  } else {
    Some(sum)
  }
}

///|
pub impl BoundedMeasure for Int with fn sub(self, other) {
  self - other
}

///|
pub impl BoundedMeasure for Double with fn max_value() {
  @double.infinity
}

///|
pub impl BoundedMeasure for Double with fn checked_add(self, other) {
  Some(self + other)
}

///|
pub impl BoundedMeasure for Double with fn sub(self, other) {
  self - other
}
