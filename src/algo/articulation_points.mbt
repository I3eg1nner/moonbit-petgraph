///|
/// Sentinel used for "no parent" / "not yet discovered" slots in the
/// articulation-point tracker, standing in for petgraph's `usize::MAX`.
///
/// `parent` uses it to mark the root of a DFS tree; `low` / `disc` are only ever
/// read after the corresponding node has been discovered, so the initial value
/// merely has to be larger than every possible discovery time.
const AP_UNDEFINED : Int = 2147483647

///|
/// Small helper enum that defines the various split-up recursion steps of
/// Tarjan's algorithm, mirroring petgraph's `RecursionStep`.
///
/// The recursive formulation is turned into an explicit work stack: a
/// `BaseStep` discovers a node and schedules one `ProcessChildStep` per incident
/// edge plus a final `RootMoreThanTwoChildrenCheck`; a `ProcessChildStep` either
/// recurses (pushing `NoBackEdgeConditionCheck` + `BaseStep`) or folds a back
/// edge into `low`.
priv enum RecursionStep {
  BaseStep(Int)
  ProcessChildStep(Int, Int)
  NoBackEdgeConditionCheck(Int, Int)
  RootMoreThanTwoChildrenCheck(Int)
}

///|
/// Internal auxiliary helper struct for the "global" variables of Tarjan's
/// articulation-point search, ported from petgraph's
/// `ArticulationPointTracker`.
///
/// `articulation_points` is a dense `Array[Bool]` (petgraph uses a `HashSet`);
/// node ids are contiguous small integers, so a flat array is both simpler and
/// gives a deterministic ascending-order result.
priv struct ArticulationPointTracker {
  visited : Array[Bool]
  low : Array[Int]
  disc : Array[Int]
  parent : Array[Int]
  mut time : Int
  articulation_points : Array[Bool]
}

///|
/// Allocate a tracker for a graph with `graph_size` nodes.
fn ArticulationPointTracker::new(graph_size : Int) -> ArticulationPointTracker {
  {
    visited: Array::make(graph_size, false),
    low: Array::make(graph_size, AP_UNDEFINED),
    disc: Array::make(graph_size, AP_UNDEFINED),
    parent: Array::make(graph_size, AP_UNDEFINED),
    time: 0,
    articulation_points: Array::make(graph_size, false),
  }
}

///|
/// Find the articulation points of a graph using
/// [Tarjan's algorithm](https://en.wikipedia.org/wiki/Biconnected_component).
///
/// An articulation point (cut vertex) is a node whose removal would increase the
/// number of connected components of the graph. The graph is meant to be
/// undirected: for an undirected `Graph`, `neighbors_directed(n, Outgoing)`
/// yields every incident neighbour, which is exactly the edge set petgraph's
/// `g.edges(n)` walks.
///
/// Port of petgraph's `algo::articulation_points::articulation_points`, keeping
/// its iterative work-stack formulation. petgraph returns an unordered
/// `HashSet`; we return the node ids in **ascending index order** so the result
/// is deterministic.
///
/// # Complexity
/// * Time complexity: **O(|V| + |E|)**.
/// * Auxiliary space: **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // A - B - C: removing B disconnects A from C.
///   let g = @graph.from_edges_undirected([(0, 1), (1, 2)])
///   let pts = [ for n in @algo.articulation_points(g) => n.index() ]
///   debug_inspect(pts, content="[1]")
/// }
/// ```
pub fn[G : @graph.NeighborSource] articulation_points(
  g : G,
) -> Array[@graph.NodeId] {
  let graph_size = g.node_count()
  let auxiliary_const = ArticulationPointTracker::new(graph_size)
  for node in g.node_ids() {
    let node_id = node.index()
    if !auxiliary_const.visited[node_id] {
      articulation_points_dfs(g, node_id, auxiliary_const)
    }
  }
  let out = []
  for i in 0..<graph_size {
    if auxiliary_const.articulation_points[i] {
      out.push(@graph.NodeId::new(i))
    }
  }
  out
}

///|
/// Helper that performs the required DFS in an iterative manner, port of
/// petgraph's `_dfs`.
///
/// `children_count` is local to one DFS tree, so the "root with more than one
/// child" rule only counts children discovered from `target_node`.
fn[G : @graph.NeighborSource] articulation_points_dfs(
  g : G,
  target_node : Int,
  tracker : ArticulationPointTracker,
) -> Unit {
  let stack : Array[RecursionStep] = [BaseStep(target_node)]
  let children_count = Array::make(tracker.visited.length(), 0)
  while stack.pop() is Some(recursion_step) {
    match recursion_step {
      BaseStep(current_node) => {
        tracker.visited[current_node] = true
        tracker.disc[current_node] = tracker.time
        tracker.low[current_node] = tracker.time
        tracker.time = tracker.time + 1
        // Scheduled first, so it is popped *after* every child has been folded
        // back in.
        stack.push(RootMoreThanTwoChildrenCheck(current_node))
        for
          child in g.neighbors_directed(
            @graph.NodeId::new(current_node),
            Outgoing,
          ) {
          stack.push(ProcessChildStep(current_node, child.index()))
        }
      }
      ProcessChildStep(current_node, child_node) =>
        if !tracker.visited[child_node] {
          // Tree edge: recurse, then run the no-back-edge check on return.
          tracker.parent[child_node] = current_node
          children_count[current_node] = children_count[current_node] + 1
          stack.push(NoBackEdgeConditionCheck(current_node, child_node))
          stack.push(BaseStep(child_node))
        } else if child_node != tracker.parent[current_node] {
          // Back edge (the edge to the DFS parent does not count).
          if tracker.disc[child_node] < tracker.low[current_node] {
            tracker.low[current_node] = tracker.disc[child_node]
          }
        }
      NoBackEdgeConditionCheck(current_node, child_node) => {
        if tracker.low[child_node] < tracker.low[current_node] {
          tracker.low[current_node] = tracker.low[child_node]
        }
        // A non-root node is a cut vertex when some child's subtree cannot reach
        // above it.
        if tracker.parent[current_node] != AP_UNDEFINED &&
          tracker.low[child_node] >= tracker.disc[current_node] {
          tracker.articulation_points[current_node] = true
        }
      }
      RootMoreThanTwoChildrenCheck(current_node) => {
        // The root of a DFS tree is a cut vertex iff it has 2+ DFS children.
        let child_count = children_count[current_node]
        if tracker.parent[current_node] == AP_UNDEFINED && child_count > 1 {
          tracker.articulation_points[current_node] = true
        }
      }
    }
  }
}
