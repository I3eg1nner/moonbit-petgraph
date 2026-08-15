// Faithful ports of petgraph's `tests/unionfind.rs`, one MoonBit `test` per
// upstream `#[test]`. Each test is annotated with the original name. These sit
// alongside the pre-existing structured tests in `unionfind_test.mbt`.
//
// API-shape adaptations from the Rust original (kept minimal):
//   * petgraph's `Ix` generic (u8/u16/u32/usize) collapses to plain `Int`, so
//     the `uf_u8` / `uf_u16` variants would be byte-for-byte identical here.
//     They are ported once below (`uf_u8`) and noted as merged.
//   * The `_checked` tests use petgraph's `try_find` / `try_union` which return
//     `Result`; our `try_*` return `Option`. `Ok(false)`/`Ok(true)` map to
//     `Some(false)`/`Some(true)`, and the out-of-bounds `Err(_)` maps to `None`.
//   * petgraph's `equiv` / `try_equiv` map to our `same_set` / `try_same_set`.

///|
/// Count the number of distinct representatives across `0..n` (ported stand-in
/// for petgraph's `(0..n).map(|i| u.find(i)).collect::<HashSet<_>>().len()`).
fn ported_distinct_sets(u : @unionfind.UnionFind, n : Int) -> Int {
  let seen : Map[Int, Unit] = Map([])
  for i in 0..<n {
    seen[u.find(i)] = ()
  }
  seen.length()
}

///|
test "uf_test: union merges, find agrees" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    assert_eq(u.find(i), i)
    assert_eq(u.find_mut(i), i)
    assert_false(u.union(i, i))
  }
  let _ = u.union(0, 1)
  assert_eq(u.find(0), u.find(1))
  let _ = u.union(1, 3)
  let _ = u.union(1, 4)
  let _ = u.union(4, 7)
  assert_eq(u.find(0), u.find(3))
  assert_eq(u.find(1), u.find(3))
  assert_true(u.find(0) != u.find(2))
  assert_eq(u.find(7), u.find(0))
  let _ = u.union(5, 6)
  assert_eq(u.find(6), u.find(5))
  assert_true(u.find(6) != u.find(7))
  // There are now 3 disjoint sets.
  debug_inspect(ported_distinct_sets(u, n), content="3")
}

///|
test "uf_test_checked: try_find / try_union agree" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    // try_find(i) == Some(i); try_union(i,i) == Some(false) (Ok(false) in Rust).
    json_inspect(u.try_find(i), content=[i])
    json_inspect(u.try_union(i, i), content=[false])
  }
  // try_union is in-bounds here, so it returns Some(_) (Rust: is_ok()).
  // Note: `Int?` derives Eq but only Show (not Debug), so we compare the
  // Options with `==`/`!=` under assert_true rather than `assert_eq` to avoid
  // the deprecated Show-for-debug path.
  assert_true(u.try_union(0, 1) is Some(_))
  assert_true(u.try_find(0) == u.try_find(1))
  assert_true(u.try_find(0) is Some(_))
  assert_true(u.try_union(1, 3) is Some(_))
  assert_true(u.try_union(1, 4) is Some(_))
  assert_true(u.try_union(4, 7) is Some(_))
  assert_true(u.try_find(0) == u.try_find(3))
  assert_true(u.try_find(1) == u.try_find(3))
  assert_true(u.try_find(0) is Some(_))
  assert_true(u.try_find(1) is Some(_))
  assert_true(u.try_find(0) != u.try_find(2))
  assert_true(u.try_find(7) == u.try_find(0))
  assert_true(u.try_union(5, 6) is Some(_))
  assert_true(u.try_find(6) == u.try_find(5))
  assert_true(u.try_find(6) != u.try_find(7))
  // 3 disjoint sets.
  debug_inspect(ported_distinct_sets(u, n), content="3")
}

///|
test "uf_test_with_equiv: same_set agrees" {
  // petgraph's `equiv` maps to our `same_set`.
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    assert_eq(u.find(i), i)
    assert_eq(u.find_mut(i), i)
    assert_true(u.same_set(i, i))
  }
  let _ = u.union(0, 1)
  assert_true(u.same_set(0, 1))
  let _ = u.union(1, 3)
  let _ = u.union(1, 4)
  let _ = u.union(4, 7)
  assert_true(u.same_set(0, 7))
  assert_true(u.same_set(1, 3))
  assert_false(u.same_set(0, 2))
  assert_true(u.same_set(7, 0))
  let _ = u.union(5, 6)
  assert_true(u.same_set(6, 5))
  assert_false(u.same_set(6, 7))
  debug_inspect(ported_distinct_sets(u, n), content="3")
}

///|
test "uf_test_with_checked_equiv: try_same_set agrees" {
  // petgraph's `try_equiv` (Result) maps to our `try_same_set` (Option):
  // Ok(true)/Ok(false) -> Some(true)/Some(false).
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    assert_eq(u.find(i), i)
    assert_eq(u.find_mut(i), i)
    json_inspect(u.try_same_set(i, i), content=[true])
  }
  let _ = u.union(0, 1)
  json_inspect(u.try_same_set(0, 1), content=[true])
  let _ = u.union(1, 3)
  let _ = u.union(1, 4)
  let _ = u.union(4, 7)
  json_inspect(u.try_same_set(0, 7), content=[true])
  json_inspect(u.try_same_set(1, 3), content=[true])
  json_inspect(u.try_same_set(0, 2), content=[false])
  json_inspect(u.try_same_set(7, 0), content=[true])
  let _ = u.union(5, 6)
  json_inspect(u.try_same_set(6, 5), content=[true])
  json_inspect(u.try_same_set(6, 7), content=[false])
  debug_inspect(ported_distinct_sets(u, n), content="3")
}

///|
/// Deterministic LCG replacing Rust's `rand`/`ChaChaRng` for the randomized
/// tests below. Fixed seed -> reproducible. (glibc-style constants.)
struct Lcg {
  mut state : UInt
}

///|
fn Lcg::new(seed : UInt) -> Lcg {
  { state: seed }
}

///|
/// Next pseudo-random non-negative `Int` in `[0, bound)`.
fn Lcg::next_below(self : Lcg, bound : Int) -> Int {
  self.state = self.state * 1103515245U + 12345U
  // Use high bits (better distributed for an LCG).
  let v = (self.state >> 16).reinterpret_as_int() & 0x7fff
  v % bound
}

///|
test "uf_rand: random unions stay consistent (deterministic LCG)" {
  // petgraph uses `n = 1 << 14` and 100 random unions; we keep n = 1 << 14 and
  // 100 iterations, but draw indices from a seeded LCG for reproducibility.
  let n = 1 << 14
  let rng = Lcg::new(0x1234_5678)
  let u = @unionfind.UnionFind::new(n)
  for _ in 0..<100 {
    let a = rng.next_below(n)
    let b = rng.next_below(n)
    let ar = u.find(a)
    let br = u.find(b)
    // union returns true iff a and b were in different sets beforehand.
    assert_eq(ar != br, u.union(a, b))
  }
}

///|
test "uf_u8 (== uf_u16/uf_u32, Ix collapses to Int): random unions consistent" {
  // petgraph parameterizes this over u8/u16/u32; since our index type is `Int`,
  // those variants are identical and are merged into this single test. We use a
  // domain of 256 (the u8 range) and 256*8 iterations, as in the u8 original.
  let n = 256
  let rng = Lcg::new(0xDEAD_BEEF)
  let u = @unionfind.UnionFind::new(n)
  for _ in 0..<(n * 8) {
    let a = rng.next_below(n)
    let b = rng.next_below(n)
    let ar = u.find(a)
    let br = u.find(b)
    assert_eq(ar != br, u.union(a, b))
  }
}

///|
test "uf_u8_checked (== checked variants, Ix collapses to Int): try_* consistent" {
  // Checked counterpart of the above; try_find/try_union are always in-bounds
  // here so they return Some(_).
  let n = 256
  let rng = Lcg::new(0xCAFE_F00D)
  let u = @unionfind.UnionFind::new(n)
  for _ in 0..<(n * 8) {
    let a = rng.next_below(n)
    let b = rng.next_below(n)
    let ar = u.try_find(a).unwrap()
    let br = u.try_find(b).unwrap()
    assert_eq(ar != br, u.try_union(a, b).unwrap())
  }
}

///|
test "labeling: into_labeling collapses everything to one label" {
  let u = @unionfind.UnionFind::new(48)
  for i in 0..<24 {
    let _ = u.union(i + 1, i)
  }
  for i = 25; i < 47; i = i + 1 {
    let _ = u.union(i, i + 1)
  }
  let _ = u.union(23, 25)
  let _ = u.union(24, 23)
  let v = u.into_labeling()
  // All labels equal v[0].
  let first = v[0]
  for x in v {
    assert_eq(x, first)
  }
}

///|
test "uf_incremental: new_set grows the structure" {
  let u = @unionfind.UnionFind::new_empty()
  assert_eq(u.new_set(), 0)
  assert_eq(u.new_set(), 1)
  assert_eq(u.len(), 2)
  let _ = u.union(0, 1)
  assert_eq(u.find(0), u.find(1))
  assert_eq(u.new_set(), 2)
  assert_eq(u.new_set(), 3)
  let _ = u.union(1, 3)
  assert_eq(u.new_set(), 4)
  let _ = u.union(1, 4)
  assert_eq(u.new_set(), 5)
  assert_eq(u.new_set(), 6)
  assert_eq(u.new_set(), 7)
  assert_eq(u.len(), 8)
  let _ = u.union(4, 7)
  assert_eq(u.find(0), u.find(3))
  assert_eq(u.find(1), u.find(3))
  assert_true(u.find(0) != u.find(2))
  assert_eq(u.find(7), u.find(0))
  let _ = u.union(5, 6)
  assert_eq(u.find(6), u.find(5))
  assert_true(u.find(6) != u.find(7))
  // 3 disjoint sets.
  debug_inspect(ported_distinct_sets(u, u.len()), content="3")
}

///|
test "uf_test_out_of_bounds: try_* return None on bad index" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    let _ = u.find(i)
    let _ = u.find_mut(i)
    let _ = u.union(i, i)
  }
  // Rust: try_find(50)/try_find_mut(50) are None.
  json_inspect(u.try_find(50), content=null)
  // Rust returns Err(50)/Err(30) here; our Option-based API returns None.
  json_inspect(u.try_union(1, 50), content=null)
  json_inspect(u.try_union(50, 1), content=null)
  json_inspect(u.try_union(30, 50), content=null)
  json_inspect(u.try_union(50, 30), content=null)
  // equiv counterparts (Rust: try_equiv -> Err) -> our try_same_set -> None.
  json_inspect(u.try_same_set(1, 50), content=null)
  json_inspect(u.try_same_set(50, 1), content=null)
  json_inspect(u.try_same_set(30, 50), content=null)
  json_inspect(u.try_same_set(50, 30), content=null)
}
