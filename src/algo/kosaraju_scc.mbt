///|
/// Compute the strongly connected components using Kosaraju's algorithm.
///
/// Returns a list of SCCs. The order of node ids *within* each SCC is arbitrary,
/// but the SCCs themselves are produced in **reverse topological order**
/// (postorder), matching petgraph's `algo::kosaraju_scc`. For an undirected
/// graph the SCCs are simply the connected components.
///
/// Two passes, mirroring petgraph:
///   1. A post-order DFS over the **reversed** graph (incoming edges) records a
///      finishing order.
///   2. A DFS over the **forward** graph (outgoing edges), processing roots in
///      decreasing finishing time, collects each reachable tree as one SCC.
///
/// # Example
/// ```mbt check
/// test {
///   // {0,1,2} form a cycle (one SCC); node 3 stands alone.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([
///     (0, 1),
///     (1, 2),
///     (2, 0),
///     (2, 3),
///   ])
///   let sccs = @algo.kosaraju_scc(g)
///   let sizes = sccs.map(fn(c) { c.length() })
///   sizes.sort()
///   debug_inspect(sizes, content="[1, 3]")
/// }
/// ```
pub fn[N, E] kosaraju_scc(
  g : @graph.Graph[N, E],
) -> Array[Array[@graph.NodeId]] {
  let n = g.node_count()

  // Phase 1: post-order finishing times over the reversed graph.
  let finish_order = post_order(g, Incoming)

  // Phase 2: forward DFS, roots taken in reverse finishing order.
  let visited = Array::make(n, false)
  let sccs : Array[Array[@graph.NodeId]] = []
  for k = finish_order.length() - 1; k >= 0; k = k - 1 {
    let root = finish_order[k]
    if visited[root.index()] {
      continue
    }
    let scc = []
    let stack = [root]
    visited[root.index()] = true
    while stack.pop() is Some(node) {
      scc.push(node)
      for next in g.neighbors_directed(node, Outgoing) {
        if !visited[next.index()] {
          visited[next.index()] = true
          stack.push(next)
        }
      }
    }
    sccs.push(scc)
  }
  sccs
}

///|
/// Iterative DFS post-order over the whole graph, walking edges in direction
/// `dir`. Returns nodes in the order they *finish* (all descendants emitted
/// before the node itself), starting a fresh DFS from each not-yet-visited node.
fn[N, E] post_order(
  g : @graph.Graph[N, E],
  dir : @graph.Direction,
) -> Array[@graph.NodeId] {
  let n = g.node_count()
  let discovered = Array::make(n, false)
  let finished = Array::make(n, false)
  let order : Array[@graph.NodeId] = []
  for i in 0..<n {
    let start = @graph.NodeId::new(i)
    if discovered[i] {
      continue
    }
    // Stack of nodes; a node is processed twice (pre then post) using the
    // `discovered`/`finished` marks, matching DfsPostOrder semantics.
    let stack = [start]
    while stack.last() is Some(nx) {
      if !discovered[nx.index()] {
        discovered[nx.index()] = true
        for succ in g.neighbors_directed(nx, dir) {
          if !discovered[succ.index()] {
            stack.push(succ)
          }
        }
      } else {
        stack.pop() |> ignore
        if !finished[nx.index()] {
          finished[nx.index()] = true
          order.push(nx)
        }
      }
    }
  }
  order
}
