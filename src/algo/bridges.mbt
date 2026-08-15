///|
/// Sentinel for "no back edge seen yet", standing in for petgraph's
/// `usize::MAX`. Any real discovery time is smaller, so `min` folds work.
const BRIDGE_NO_BACKEDGE : Int = 2147483647

///|
/// One frame of the iterative bridge-finding DFS: a node plus a cursor into its
/// materialised neighbour list.
///
/// petgraph keeps the live `G::Neighbors` iterator inside the stack frame; a
/// MoonBit `Iter` is single-use and cannot be resumed across loop iterations, so
/// the neighbours are collected once per frame and walked with `cursor`.
priv struct BridgeFrame {
  node : @graph.NodeId
  neighbors : Array[@graph.NodeId]
  mut cursor : Int
}

///|
/// Find all [bridges](https://en.wikipedia.org/wiki/Bridge_(graph_theory)) in a
/// simple undirected graph.
///
/// A bridge is an edge whose removal increases the number of connected
/// components. Port of petgraph's `algo::bridges::bridges`: run a DFS forest
/// recording each node's discovery time and the earliest discovery time
/// reachable by a back edge from its subtree, then keep every edge whose lower
/// subtree cannot reach past its parent.
///
/// Returns the bridging edges in **edge-insertion order**, matching petgraph's
/// `graph.edge_references().filter(..)`.
///
/// # Complexity
/// * Time complexity: **O(|V| + |E|)**.
/// * Auxiliary space: **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 - 1 - 2 - 3, plus the cycle 2 - 3 - 4 - 2.
///   let g = @graph.from_edges_undirected([(0, 1), (1, 2), (2, 3), (3, 4), (2, 4)])
///   let bs = [ for e in @algo.bridges(g) => e.index() ]
///   debug_inspect(bs, content="[0, 1]")
/// }
/// ```
pub fn[N, E] bridges(graph : @graph.Graph[N, E]) -> Array[@graph.EdgeId] {
  let node_bound = graph.node_count()
  let mut clock = 0
  // If and when a node was visited by the dfs (`-1` = not yet).
  let visit_time = Array::make(node_bound, -1)
  // Lowest time on a node that is the target of a back-edge from the subtree
  // rooted at the indexed node.
  let earliest_backedge = Array::make(node_bound, BRIDGE_NO_BACKEDGE)
  for start in 0..<node_bound {
    // If node hasn't been visited yet, make it the root of a new dfs-tree in
    // the forest.
    if visit_time[start] == -1 {
      visit_time[start] = clock
      clock = clock + 1
      let start_node = @graph.NodeId::new(start)
      let stack : Array[BridgeFrame] = [
        {
          node: start_node,
          neighbors: graph.neighbors(start_node).to_array(),
          cursor: 0,
        },
      ]
      while stack.last() is Some(frame) {
        let node = frame.node
        let node_index = node.index()
        let parent = if stack.length() > 1 {
          Some(stack[stack.length() - 2].node)
        } else {
          None
        }
        if frame.cursor < frame.neighbors.length() {
          // Pre-order DFS.
          let child = frame.neighbors[frame.cursor]
          frame.cursor = frame.cursor + 1
          if parent != Some(child) {
            let child_index = child.index()
            let time = visit_time[child_index]
            if time != -1 {
              if time < earliest_backedge[node_index] {
                earliest_backedge[node_index] = time
              }
            } else {
              visit_time[child_index] = clock
              clock = clock + 1
              stack.push({
                node: child,
                neighbors: graph.neighbors(child).to_array(),
                cursor: 0,
              })
            }
          }
        } else {
          // Post-order DFS: fold this subtree's earliest back edge into the
          // parent's.
          if parent is Some(p) {
            let parent_index = p.index()
            if earliest_backedge[node_index] < earliest_backedge[parent_index] {
              earliest_backedge[parent_index] = earliest_backedge[node_index]
            }
          }
          stack.pop() |> ignore
        }
      }
    }
  }
  let out = []
  for edge in graph.edge_ids() {
    guard graph.edge_endpoints(edge) is Some((source, target)) else { continue }
    let source_index = source.index()
    let target_index = target.index()
    // All nodes have been visited by the time we get here. The node with the
    // lower visit time is the "parent" in the dfs-forest created above.
    let (parent, node) = if visit_time[source_index] < visit_time[target_index] {
      (source_index, target_index)
    } else {
      (target_index, source_index)
    }
    // If there's no back-edge to before parent, then the only way from parent to
    // here is directly from parent, so it's a bridge edge.
    if earliest_backedge[node] > visit_time[parent] {
      out.push(edge)
    }
  }
  out
}
