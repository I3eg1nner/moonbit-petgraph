// Black-box tests for the `unionfind` package, ported from petgraph's
// `tests/unionfind.rs`. They exercise only the public API via `@unionfind`.

///|
/// Count the number of distinct representatives across `0..n`.
fn distinct_sets(u : @unionfind.UnionFind, n : Int) -> Int {
  let seen : Map[Int, Unit] = Map([])
  for i in 0..<n {
    seen[u.find(i)] = ()
  }
  seen.length()
}

///|
test "new sets are disjoint singletons" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  debug_inspect(u.len(), content="8")
  debug_inspect(u.is_empty(), content="false")
  for i in 0..<n {
    // Each element is its own representative.
    assert_eq(u.find(i), i)
    assert_eq(u.find_mut(i), i)
    // Union of an element with itself never merges.
    assert_eq(u.union(i, i), false)
  }
  // All 8 are distinct.
  debug_inspect(distinct_sets(u, n), content="8")
}

///|
test "union merges and find agrees (uf_test)" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
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
  // There are now exactly 3 disjoint sets:
  //   {0,1,3,4,7}, {2}, {5,6}
  debug_inspect(distinct_sets(u, n), content="3")
}

///|
test "union return value reflects whether a merge happened" {
  let u = @unionfind.UnionFind::new(5)
  // First union of two different sets merges -> true.
  debug_inspect(u.union(0, 1), content="true")
  // Repeating the same union does nothing -> false.
  debug_inspect(u.union(0, 1), content="false")
  debug_inspect(u.union(1, 0), content="false")
  // Merge a fresh pair -> true.
  debug_inspect(u.union(2, 3), content="true")
  // Now joining the two existing sets merges them -> true.
  debug_inspect(u.union(1, 2), content="true")
  // Already joined -> false.
  debug_inspect(u.union(0, 3), content="false")
  // Element with itself -> false.
  debug_inspect(u.union(4, 4), content="false")
}

///|
test "same_set (equiv)" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    assert_true(u.same_set(i, i))
  }
  let _ = u.union(0, 1)
  assert_true(u.same_set(0, 1))
  let _ = u.union(1, 3)
  let _ = u.union(1, 4)
  let _ = u.union(4, 7)
  assert_true(u.same_set(0, 7))
  assert_true(u.same_set(1, 3))
  assert_true(!u.same_set(0, 2))
  assert_true(u.same_set(7, 0))
  let _ = u.union(5, 6)
  assert_true(u.same_set(6, 5))
  assert_true(!u.same_set(6, 7))
  debug_inspect(distinct_sets(u, n), content="3")
}

///|
test "long chains collapse to a single set" {
  let n = 100
  let u = @unionfind.UnionFind::new(n)
  // Chain everything together: 0-1, 1-2, ..., 98-99.
  for i in 0..<(n - 1) {
    assert_true(u.union(i, i + 1))
  }
  // Everything is now one set.
  debug_inspect(distinct_sets(u, n), content="1")
  let root = u.find(0)
  for i in 0..<n {
    assert_eq(u.find(i), root)
  }
}

///|
test "into_labeling: every element gets one canonical label" {
  // Port of petgraph's `labeling` test.
  let u = @unionfind.UnionFind::new(48)
  for i in 0..<24 {
    let _ = u.union(i + 1, i)
  }
  for i = 25; i < 47; i = i + 1 {
    let _ = u.union(i, i + 1)
  }
  let _ = u.union(23, 25)
  let _ = u.union(24, 23)
  let labels = u.into_labeling()
  debug_inspect(labels.length(), content="48")
  // All elements collapse to the same label.
  let first = labels[0]
  for x in labels {
    assert_eq(x, first)
  }
}

///|
test "into_labeling on multiple disjoint sets" {
  let u = @unionfind.UnionFind::new(6)
  // Two sets: {0,1,2} and {3,4,5}.
  let _ = u.union(0, 1)
  let _ = u.union(1, 2)
  let _ = u.union(3, 4)
  let _ = u.union(4, 5)
  let labels = u.into_labeling()
  // Within each group the label is identical; across groups it differs.
  assert_eq(labels[0], labels[1])
  assert_eq(labels[1], labels[2])
  assert_eq(labels[3], labels[4])
  assert_eq(labels[4], labels[5])
  assert_true(labels[0] != labels[3])
}

///|
test "incremental new_set (uf_incremental)" {
  let u = @unionfind.UnionFind::new_empty()
  debug_inspect(u.is_empty(), content="true")
  debug_inspect(u.new_set(), content="0")
  debug_inspect(u.new_set(), content="1")
  debug_inspect(u.len(), content="2")
  let _ = u.union(0, 1)
  assert_eq(u.find(0), u.find(1))
  debug_inspect(u.new_set(), content="2")
  debug_inspect(u.new_set(), content="3")
  let _ = u.union(1, 3)
  debug_inspect(u.new_set(), content="4")
  let _ = u.union(1, 4)
  debug_inspect(u.new_set(), content="5")
  debug_inspect(u.new_set(), content="6")
  debug_inspect(u.new_set(), content="7")
  debug_inspect(u.len(), content="8")
  let _ = u.union(4, 7)
  assert_eq(u.find(0), u.find(3))
  assert_eq(u.find(1), u.find(3))
  assert_true(u.find(0) != u.find(2))
  assert_eq(u.find(7), u.find(0))
  let _ = u.union(5, 6)
  assert_eq(u.find(6), u.find(5))
  assert_true(u.find(6) != u.find(7))
  debug_inspect(distinct_sets(u, u.len()), content="3")
}

///|
test "try_* out of bounds (uf_test_out_of_bounds)" {
  let n = 8
  let u = @unionfind.UnionFind::new(n)
  for i in 0..<n {
    let _ = u.find(i)
    let _ = u.find_mut(i)
    let _ = u.union(i, i)
  }
  // try_find / try_same_set / try_union return None on out-of-bounds.
  // (Option serializes to `null` for None and `[v]` for Some(v).)
  json_inspect(u.try_find(50), content=null)
  json_inspect(u.try_find(-1), content=null)
  json_inspect(u.try_union(1, 50), content=null)
  json_inspect(u.try_union(50, 1), content=null)
  json_inspect(u.try_union(30, 50), content=null)
  json_inspect(u.try_union(50, 30), content=null)
  json_inspect(u.try_same_set(1, 50), content=null)
  json_inspect(u.try_same_set(50, 1), content=null)
  // In-bounds try_* return Some(...).
  json_inspect(u.try_find(0), content=[0])
  json_inspect(u.try_union(0, 1), content=[true])
  json_inspect(u.try_union(0, 1), content=[false])
  json_inspect(u.try_same_set(0, 1), content=[true])
  json_inspect(u.try_same_set(0, 2), content=[false])
  // x == y short-circuits to Some(false) even when out of bounds.
  json_inspect(u.try_union(50, 50), content=[false])
}

///|
test "structured larger scenario: pairwise unions match find" {
  // Deterministic structured scenario standing in for petgraph's randomized
  // `uf_rand`. We apply a fixed sequence of unions and assert that the union
  // return value always matches whether the representatives differed
  // beforehand, then check the final partition.
  let n = 64
  let u = @unionfind.UnionFind::new(n)
  // A pseudo-random but deterministic sequence (linear congruential).
  let mut state = 12345
  fn next_index() -> Int {
    state = (state * 1103515245 + 12345) & 0x7fffffff
    state % n
  }

  for _ in 0..<200 {
    let a = next_index()
    let b = next_index()
    let ar = u.find(a)
    let br = u.find(b)
    // union returns true iff a and b were in different sets.
    assert_eq(ar != br, u.union(a, b))
    // After union they must be in the same set.
    assert_true(u.same_set(a, b))
  }
  // Sanity: into_labeling must agree with find for every element.
  let labels = u.into_labeling()
  for i in 0..<n {
    assert_eq(labels[i], u.find(i))
  }
}
