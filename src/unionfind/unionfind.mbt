// `UnionFind` is a disjoint-set data structure over integer elements
// indexed from `0` to `n - 1`.
//
// This is a MoonBit port of petgraph's `UnionFind<K>`. Unlike petgraph we drop
// the generic `Ix` index type and use plain `Int` indices throughout.
//
// Internally each element stores the index of its parent; the representative of
// a set stores its own index. Union by rank keeps the trees shallow, and `find`
// applies path compression (halving) so amortized cost is effectively constant.
//
// Out-of-bounds handling: the panicking methods (`find`, `find_mut`, `union`,
// `same_set`) abort, mirroring petgraph's `expect`/`unwrap`. The `try_*`
// variants return `Int?` / `Bool?` instead.

///|
/// `UnionFind` (disjoint-set) over integer elements `0..n`.
///
/// `parent[i]` is the parent of element `i`; `i` is a root iff `parent[i] == i`.
/// `rank[i]` is only meaningful for roots and is used for union-by-rank.
pub struct UnionFind {
  parent : Array[Int]
  rank : Array[Int]
}

///|
/// Create a new `UnionFind` of `n` disjoint singleton sets `0..n`.
///
/// # Example
/// ```mbt check
/// test {
///   let u = @unionfind.UnionFind::new(3)
///   debug_inspect(u.len(), content="3")
///   // Every element starts as its own representative.
///   debug_inspect(u.find(0), content="0")
/// }
/// ```
pub fn UnionFind::new(n : Int) -> UnionFind {
  { parent: Array::makei(n, i => i), rank: Array::make(n, 0) }
}

///|
/// Create a new, empty `UnionFind` with no elements.
pub fn UnionFind::new_empty() -> UnionFind {
  { parent: [], rank: [] }
}

///|
/// The number of elements in the data structure.
pub fn UnionFind::len(self : UnionFind) -> Int {
  self.parent.length()
}

///|
/// Returns `true` if there are no elements.
pub fn UnionFind::is_empty(self : UnionFind) -> Bool {
  self.parent.length() == 0
}

///|
/// Add a new singleton set and return its index.
///
/// The new set is always appended to the end, so the returned index equals the
/// number of elements before the call. Amortized O(1).
pub fn UnionFind::new_set(self : UnionFind) -> Int {
  let retval = self.parent.length()
  self.rank.push(0)
  self.parent.push(retval)
  retval
}

///|
/// Return the representative for `x`, applying path compression (halving).
///
/// Both `find` and `find_mut` mutate the internal `parent` array via path
/// compression; in MoonBit there is no `&self` vs `&mut self` distinction here,
/// so they share one implementation.
///
/// Aborts if `x` is out of bounds.
pub fn UnionFind::find(self : UnionFind, x : Int) -> Int {
  match self.try_find(x) {
    Some(rep) => rep
    None => abort("UnionFind::find: index out of bounds")
  }
}

///|
/// Alias of `find`: returns the representative for `x` with path compression.
///
/// Aborts if `x` is out of bounds.
pub fn UnionFind::find_mut(self : UnionFind, x : Int) -> Int {
  self.find(x)
}

///|
/// Return the representative for `x`, or `None` if `x` is out of bounds.
///
/// Applies path compression by halving: every node on the path is repointed to
/// its grandparent, flattening the tree for faster future lookups.
pub fn UnionFind::try_find(self : UnionFind, x : Int) -> Int? {
  if x < 0 || x >= self.parent.length() {
    return None
  }
  // Path halving: repoint each visited node to its grandparent.
  let mut x = x
  let mut parent = self.parent[x]
  while parent != x {
    let grandparent = self.parent[parent]
    self.parent[x] = grandparent
    x = parent
    parent = grandparent
  }
  Some(x)
}

///|
/// Unify the sets containing `x` and `y`.
///
/// Returns `true` if they were in different sets (and are now merged), `false`
/// if they were already in the same set.
///
/// Aborts if `x` or `y` is out of bounds (unless `x == y`).
///
/// # Example
/// ```mbt check
/// test {
///   let u = @unionfind.UnionFind::new(4)
///   u.union(0, 1) |> ignore
///   u.union(2, 3) |> ignore
///   debug_inspect(u.same_set(0, 1), content="true")
///   debug_inspect(u.same_set(0, 2), content="false")
///   // Merge the two pairs into a single set.
///   u.union(1, 2) |> ignore
///   debug_inspect(u.same_set(0, 3), content="true")
/// }
/// ```
pub fn UnionFind::union(self : UnionFind, x : Int, y : Int) -> Bool {
  match self.try_union(x, y) {
    Some(merged) => merged
    None => abort("UnionFind::union: index out of bounds")
  }
}

///|
/// Unify the sets containing `x` and `y`.
///
/// Returns `Some(true)` if they were unified, `Some(false)` if already the same
/// set, and `None` if `x` or `y` is out of bounds. If `x == y` the result is
/// `Some(false)` even when the index is out of bounds (matching petgraph).
pub fn UnionFind::try_union(self : UnionFind, x : Int, y : Int) -> Bool? {
  if x == y {
    return Some(false)
  }
  let xrep = match self.try_find(x) {
    Some(r) => r
    None => return None
  }
  let yrep = match self.try_find(y) {
    Some(r) => r
    None => return None
  }
  if xrep == yrep {
    return Some(false)
  }
  let xrank = self.rank[xrep]
  let yrank = self.rank[yrep]
  // Put the smaller-rank tree under the larger one.
  if xrank < yrank {
    self.parent[xrep] = yrep
  } else if xrank > yrank {
    self.parent[yrep] = xrep
  } else {
    self.parent[yrep] = xrep
    self.rank[xrep] = self.rank[xrep] + 1
  }
  Some(true)
}

///|
/// Returns `true` if `x` and `y` belong to the same set.
///
/// Aborts if `x` or `y` is out of bounds.
pub fn UnionFind::same_set(self : UnionFind, x : Int, y : Int) -> Bool {
  self.find(x) == self.find(y)
}

///|
/// Returns `Some(true)`/`Some(false)` if both indices are in bounds, or `None`
/// if `x` or `y` is out of bounds.
pub fn UnionFind::try_same_set(self : UnionFind, x : Int, y : Int) -> Bool? {
  let xrep = match self.try_find(x) {
    Some(r) => r
    None => return None
  }
  let yrep = match self.try_find(y) {
    Some(r) => r
    None => return None
  }
  Some(xrep == yrep)
}

///|
/// Return an array mapping each element to its representative (canonical label).
///
/// Fully compresses every element along the way. Two elements share a label iff
/// they are in the same set.
///
/// # Example
/// ```mbt check
/// test {
///   let u = @unionfind.UnionFind::new(3)
///   u.union(0, 2) |> ignore
///   let labels = u.into_labeling()
///   debug_inspect(labels[0] == labels[2], content="true")
///   debug_inspect(labels[0] == labels[1], content="false")
/// }
/// ```
pub fn UnionFind::into_labeling(self : UnionFind) -> Array[Int] {
  for ix in 0..<self.parent.length() {
    let rep = self.find(ix)
    self.parent[ix] = rep
  }
  self.parent
}
