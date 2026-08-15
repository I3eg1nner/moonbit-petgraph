///|
/// Build the dense adjacency matrix of `g`, the MoonBit counterpart of
/// petgraph's `GetAdjacencyMatrix::adjacency_matrix`.
///
/// `mat[a][b]` is `true` iff the edge `a -> b` exists. For an undirected graph
/// both `mat[a][b]` and `mat[b][a]` are set, so `is_adjacent` is symmetric,
/// exactly as in petgraph.
fn[N, E] adjacency_matrix(g : @graph.Graph[N, E]) -> Array[Array[Bool]] {
  let n = g.node_count()
  let mat = Array::makei(n, _ => Array::make(n, false))
  let directed = g.is_directed()
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((a, b)) else { continue }
    mat[a.index()][b.index()] = true
    if !directed {
      mat[b.index()][a.index()] = true
    }
  }
  mat
}

///|
/// Intersect two index sets, keeping the iteration order of `a`.
///
/// The MoonBit stand-in for `HashSet::intersection`. `Map[Int, Unit]` preserves
/// insertion order, which makes the whole Bron–Kerbosch recursion deterministic
/// (petgraph's `HashSet` ordering is not, but the results are compared as sets).
fn intersect_index_sets(
  a : Map[Int, Unit],
  b : Map[Int, Unit],
) -> Map[Int, Unit] {
  let out : Map[Int, Unit] = Map([])
  for k, _ in a {
    if b.contains(k) {
      out[k] = ()
    }
  }
  out
}

///|
/// Finds maximal cliques containing all the vertices in `r`, some of the
/// vertices in `p`, and none of the vertices in `x`.
///
/// Port of petgraph's `bron_kerbosch_pivot`: the Bron–Kerbosch algorithm with
/// pivoting, where the pivot `u` is the vertex of `p` with maximum degree (ties
/// resolved to the *last* maximum, matching Rust's `Iterator::max_by_key`).
/// Vertices adjacent to the pivot in both directions are skipped.
///
/// Sets are index sets (`Map[Int, Unit]` keyed by `NodeId::index()`).
fn[N, E] bron_kerbosch_pivot(
  g : @graph.Graph[N, E],
  adj_mat : Array[Array[Bool]],
  r : Map[Int, Unit],
  p : Map[Int, Unit],
  x : Map[Int, Unit],
) -> Array[Array[@graph.NodeId]] {
  let cliques : Array[Array[@graph.NodeId]] = []
  if p.length() == 0 {
    if x.length() == 0 {
      let clique = [ for k in r.keys() => @graph.NodeId::new(k) ]
      clique.sort()
      cliques.push(clique)
    }
    return cliques
  }
  // Pick the pivot u to be the vertex with max degree; `>=` reproduces Rust's
  // `max_by_key`, which keeps the last of several equal maxima.
  let mut u = -1
  let mut best = -1
  for v, _ in p {
    let deg = g.neighbors(@graph.NodeId::new(v)).count()
    if deg >= best {
      best = deg
      u = v
    }
  }
  // Candidates: everything in p that is not a (bidirectional) neighbor of u.
  let todo : Array[Int] = []
  for v, _ in p {
    if u == v || !adj_mat[u][v] || !adj_mat[v][u] {
      todo.push(v)
    }
  }
  while todo.pop() is Some(v) {
    let vid = @graph.NodeId::new(v)
    let neighbors : Map[Int, Unit] = Map([])
    for w in g.neighbors(vid) {
      neighbors[w.index()] = ()
    }
    p.remove(v)
    let next_r : Map[Int, Unit] = Map([])
    for k, _ in r {
      next_r[k] = ()
    }
    next_r[v] = ()
    let next_p = intersect_index_sets(p, neighbors)
    let next_x = intersect_index_sets(x, neighbors)
    for c in bron_kerbosch_pivot(g, adj_mat, next_r, next_p, next_x) {
      cliques.push(c)
    }
    x[v] = ()
  }
  cliques
}

///|
/// Find all maximal cliques in an undirected graph using the
/// [Bron–Kerbosch algorithm](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm)
/// with pivoting.
///
/// A clique is a set of nodes such that every node connects to every other. A
/// maximal clique is a clique that cannot be extended by including one more
/// adjacent vertex. A graph may have multiple maximal cliques.
///
/// This method may also be called on directed graphs, but one needs to ensure
/// that if an edge `(u, v)` exists, then `(v, u)` also exists.
///
/// Port of petgraph's `algo::maximal_cliques`. petgraph returns
/// `Vec<HashSet<NodeId>>`; MoonBit has no set in the prelude, so each clique is
/// returned as an `Array[NodeId]` **sorted by node index**, which additionally
/// makes the output deterministic.
///
/// Note the edge case inherited from petgraph: the empty graph yields one
/// (empty) clique, i.e. `[[]]`.
///
/// Time complexity: **O(3^(|V|/3))**. Auxiliary space: **O(|V|² + |V|k)**,
/// where k is the number of maximal cliques.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 --- 2 -- 3
///   //  \   /
///   //   \ /
///   //    1
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges_undirected([
///     (0, 1),
///     (0, 2),
///     (1, 2),
///     (2, 3),
///   ])
///   let cliques = @algo.maximal_cliques(g)
///   let out = [ for c in cliques => [ for n in c => n.index() ] ]
///   debug_inspect(out, content="[[2, 3], [0, 1, 2]]")
/// }
/// ```
pub fn[N, E] maximal_cliques(
  g : @graph.Graph[N, E],
) -> Array[Array[@graph.NodeId]] {
  let adj_mat = adjacency_matrix(g)
  let r : Map[Int, Unit] = Map([])
  let p : Map[Int, Unit] = Map([])
  for n in g.node_ids() {
    p[n.index()] = ()
  }
  let x : Map[Int, Unit] = Map([])
  bron_kerbosch_pivot(g, adj_mat, r, p, x)
}
