// White-box tests: inspect the internal `parent` / `rank` arrays directly to
// confirm union-by-rank and path-compression behavior.

///|
test "new initializes parent[i]=i and rank[i]=0" {
  let u = UnionFind::new(4)
  json_inspect(u.parent, content=[0, 1, 2, 3])
  json_inspect(u.rank, content=[0, 0, 0, 0])
}

///|
test "union by rank: equal ranks bump the surviving root's rank" {
  let u = UnionFind::new(2)
  // union(0,1): equal ranks -> parent[1]=0, rank[0]+=1.
  debug_inspect(u.union(0, 1), content="true")
  json_inspect(u.parent, content=[0, 0])
  json_inspect(u.rank, content=[1, 0])
}

///|
test "union by rank: smaller tree hangs under the larger" {
  let u = UnionFind::new(4)
  // Build a rank-1 tree rooted at 0: union(0,1).
  let _ = u.union(0, 1)
  // {0,1} root 0 rank 1; {2} rank 0. union(0,2): rank(0)>rank(2) -> parent[2]=0.
  let _ = u.union(0, 2)
  json_inspect(u.rank, content=[1, 0, 0, 0])
  json_inspect(u.parent, content=[0, 0, 0, 3])
  // Build {3} into a separate rank-1 tree by uniting with a fresh single... but
  // 3 is alone. union(3,?) needs another root. Instead union two rank-1 trees:
  let v = UnionFind::new(4)
  let _ = v.union(0, 1) // root 0, rank 1
  let _ = v.union(2, 3) // root 2, rank 1
  // union(0,2): equal rank (1) -> parent[2]=0, rank[0]=2.
  let _ = v.union(0, 2)
  json_inspect(v.rank, content=[2, 0, 1, 0])
  json_inspect(v.parent, content=[0, 0, 0, 2])
}

///|
test "find applies path compression (halving)" {
  // Construct a deliberately deep chain by manipulating via unions that keep
  // ranks low, then verify find flattens it.
  let u = UnionFind::new(4)
  // Force a chain 3 -> 2 -> 1 -> 0 by hanging equal/relevant pieces.
  // union(0,1): parent[1]=0, rank[0]=1
  let _ = u.union(0, 1)
  // union(2,3): parent[3]=2, rank[2]=1
  let _ = u.union(2, 3)
  // union(1,2): both rank-1 roots (0 and 2), equal -> parent[2]=0, rank[0]=2
  let _ = u.union(1, 2)
  // Now: parent = [0,0,0,2]; 3's chain is 3 -> 2 -> 0.
  json_inspect(u.parent, content=[0, 0, 0, 2])
  // find(3) halves: repoints 3 to its grandparent (0), returns root 0.
  debug_inspect(u.find(3), content="0")
  json_inspect(u.parent, content=[0, 0, 0, 0])
}
