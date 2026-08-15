///|
/// Check if there exists a path starting at `from` and reaching `to`.
///
/// If `from` and `to` are equal, this function returns `true`.
///
/// Port of petgraph's `algo::has_path_connecting`. petgraph's optional
/// `DfsSpace` becomes the optional `space` argument: pass a reusable
/// `@visit.Dfs` to avoid reallocating the traversal state across many queries;
/// leave it out and a fresh one is created. The supplied `space` is always
/// reset first, so its previous contents do not affect the answer.
///
/// # Complexity
/// * Time complexity: **O(|V| + |E|)**.
/// * Auxiliary space: **O(|V|)**, or **O(1)** if `space` was provided.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 -> 1 -> 2, and an isolated node 3.
///   let g = @graph.from_edges([(0, 1), (1, 2), (3, 3)])
///   let n = @graph.NodeId::new
///   debug_inspect(@algo.has_path_connecting(g, n(0), n(2)), content="true")
///   debug_inspect(@algo.has_path_connecting(g, n(2), n(0)), content="false")
/// }
/// ```
pub fn[G : @graph.NeighborSource] has_path_connecting(
  g : G,
  from : @graph.NodeId,
  to : @graph.NodeId,
  space? : @visit.Dfs,
) -> Bool {
  let dfs = match space {
    Some(dfs) => dfs
    None => @visit.Dfs::empty(g)
  }
  dfs.reset()
  dfs.move_to(from)
  while dfs.next(g) is Some(x) {
    if x == to {
      return true
    }
  }
  false
}

///|
/// Return `true` if the graph\* is bipartite.
///
/// A graph is bipartite if its nodes can be divided into two disjoint and
/// independent sets U and V such that every edge connects one node in U to one
/// in V.
///
/// Port of petgraph's `algo::is_bipartite_undirected`: a 2-colouring built on
/// top of a BFS. Like petgraph it colours the neighbourhood reported by
/// `neighbors`, which for an undirected `Graph` is every incident neighbour.
///
/// \* The algorithm checks only the subgraph that is reachable from `start`.
///
/// # Complexity
/// * Time complexity: **O(|V| + |E|)**.
/// * Auxiliary space: **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   let square = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (3, 0)])
///   let triangle = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 0)])
///   let n0 = @graph.NodeId::new(0)
///   debug_inspect(@algo.is_bipartite_undirected(square, n0), content="true")
///   debug_inspect(@algo.is_bipartite_undirected(triangle, n0), content="false")
/// }
/// ```
pub fn[G : @graph.NeighborSource] is_bipartite_undirected(
  g : G,
  start : @graph.NodeId,
) -> Bool {
  let red = @visit.VisitMap::new(g.node_count())
  red.visit(start) |> ignore
  let blue = @visit.VisitMap::new(g.node_count())
  // A plain array plus a read cursor stands in for petgraph's `VecDeque`: nodes
  // are only ever appended and consumed once, in FIFO order.
  let queue = [start]
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    let is_red = red.is_visited(node)
    let is_blue = blue.is_visited(node)
    // Every queued node carries exactly one colour.
    if is_red == is_blue {
      abort("Invariant doesn't hold")
    }
    for neighbour in g.neighbors_directed(node, Outgoing) {
      let is_neighbour_red = red.is_visited(neighbour)
      let is_neighbour_blue = blue.is_visited(neighbour)
      if (is_red && is_neighbour_red) || (is_blue && is_neighbour_blue) {
        return false
      }
      if !is_neighbour_red && !is_neighbour_blue {
        // Hasn't been visited yet: give it the opposite colour.
        if is_red {
          blue.visit(neighbour) |> ignore
        } else {
          red.visit(neighbour) |> ignore
        }
        queue.push(neighbour)
      }
    }
  }
  true
}
