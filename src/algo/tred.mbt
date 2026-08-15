///|
/// Build a representation of `g` that respects a topological order, for use with
/// `dag_transitive_reduction_closure`.
///
/// # Arguments
/// * `g`: a directed acyclic graph.
/// * `toposort`: a topological order of the nodes of `g` (e.g. from `toposort`).
///
/// # Returns
/// A pair of
/// * the adjacency list `res`: `res[i]` are the successors of the node of rank
///   `i` in `toposort`, themselves given as ranks and listed in increasing
///   (i.e. topological) order;
/// * the reciprocal `revmap` of the topological sort: `revmap[node.index()]` is
///   the rank of `node` in `toposort`.
///
/// `res` is the same graph as `g` except that node and edge weights are
/// stripped, node indices are replaced by their rank in `toposort`, and the
/// neighbors of a node are enumerated in topological order.
///
/// # Complexity
/// * Time: **O(|V| + |E|)**, auxiliary space **O(|V| + |E|)**.
///
/// Port of petgraph's `algo::tred::dag_to_toposorted_adjacency_list`, with
/// petgraph's `adj::UnweightedList` replaced by a plain array of successor
/// lists.
pub fn[N, E] dag_to_toposorted_adjacency_list(
  g : @graph.Graph[N, E],
  toposort : Array[@graph.NodeId],
) -> (Array[Array[Int]], Array[Int]) {
  let res : Array[Array[Int]] = Array::makei(toposort.length(), _ => [])
  // map from old node index to rank in toposort
  let revmap = Array::make(g.node_count(), 0)
  for ix, old_ix in toposort {
    revmap[old_ix.index()] = ix
    // Predecessors already have a smaller rank, so `revmap` is filled for them
    // and every successor list ends up sorted by increasing rank.
    for old_pre in g.neighbors_directed(old_ix, Incoming) {
      let pre = revmap[old_pre.index()]
      res[pre].push(ix)
    }
  }
  (res, revmap)
}

///|
/// Compute the transitive reduction and the transitive closure of a DAG.
///
/// The *transitive closure* of **G = (V, E)** is the graph **Gc = (V, Ec)** such
/// that **(i, j)** belongs to **Ec** iff there is a path from **i** to **j** in
/// **G**. The *transitive reduction* is the graph **Gr = (V, Er)** with **Er**
/// minimal wrt. inclusion in **E** and with the same transitive closure as
/// **G**. The transitive reduction is well-defined for acyclic graphs only.
///
/// # Arguments
/// * `g`: an adjacency list in a very specific format: node indices must be a
///   topological order, and the successors of every node must be stored in
///   topological order. Use `dag_to_toposorted_adjacency_list` to obtain such a
///   representation.
///
/// # Returns
/// The pair `(tred, tclos)` of the transitive reduction and the transitive
/// closure, in the same adjacency-list format (successor lists of `tred` are in
/// topological order; those of `tclos` are not).
///
/// # Complexity
/// * Time: **O(|V| + sum over (x, y) in Er of d(y))**, where **d(y)** is the
///   outgoing degree of **y** in the transitive closure. This is still
///   **O(|V|³)** in the worst case but performs better on many graphs.
/// * Auxiliary space: **O(|E|)**.
///
/// Port of petgraph's `algo::tred::dag_transitive_reduction_closure`, which
/// implements the algorithm of Habib, Morvan and Rampon, *On the calculation of
/// transitive reduction-closure of orders*.
pub fn dag_transitive_reduction_closure(
  g : Array[Array[Int]],
) -> (Array[Array[Int]], Array[Array[Int]]) {
  let n = g.length()
  let tred : Array[Array[Int]] = Array::makei(n, _ => [])
  let tclos : Array[Array[Int]] = Array::makei(n, _ => [])
  let mark = Array::make(n, false)
  // The algorithm relies on the nodes being enumerated in reverse topological
  // order, and on each successor list being in topological order.
  for i = n - 1; i >= 0; i = i - 1 {
    for x in g[i] {
      if !mark[x] {
        tred[i].push(x)
        tclos[i].push(x)
        // Everything reachable from `x` is reachable from `i`; the successor
        // list of `x` is already complete since `x` comes after `i`.
        let successors = tclos[x]
        let len = successors.length()
        for k in 0..<len {
          let y = successors[k]
          if !mark[y] {
            mark[y] = true
            tclos[i].push(y)
          }
        }
      }
    }
    for y in tclos[i] {
      mark[y] = false
    }
  }
  (tred, tclos)
}
