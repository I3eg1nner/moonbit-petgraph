///|
/// `MinScored(score, item)` pairs a score `K` with a payload `T` for use in a
/// max-heap (`@priority_queue.T`, which orders by `Compare`).
///
/// Its `Compare` impl is **reversed** on the score: a *smaller* score compares
/// as *greater*, so the entry with the least score is what `pop()` returns from
/// the max-heap. This is the MoonBit port of petgraph's `scored::MinScored` and
/// is what turns the standard binary max-heap into the min-priority-queue that
/// Dijkstra / A* require.
///
/// Only the score participates in ordering; the payload is ignored, matching
/// petgraph (where `MinScored` also has a total order keyed solely on the score).
struct MinScored[K, T](K, T)

///|
pub impl[K : Measure, T] Eq for MinScored[K, T] with fn equal(self, other) {
  self.0.compare(other.0) == 0
}

///|
pub impl[K : Measure, T] Compare for MinScored[K, T] with fn compare(
  self,
  other,
) {
  // Reverse the ordering on the score so the smallest score is the "maximum"
  // element of the max-heap and is popped first.
  -self.0.compare(other.0)
}
