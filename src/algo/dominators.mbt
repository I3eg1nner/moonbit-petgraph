// Compute dominators of a control-flow graph.
//
// In a directed graph with a root node **R**, a node **A** is said to
// *dominate* a node **B** iff every path from **R** to **B** contains **A**.
//
// The node **A** is said to *strictly dominate* the node **B** iff **A**
// dominates **B** and **A != B**.
//
// The node **A** is said to be the *immediate dominator* of a node **B** iff it
// strictly dominates **B** and there does not exist any node **C** where **A**
// dominates **C** and **C** dominates **B**.

///|
/// The undefined dominator sentinel, for when we have not yet discovered a
/// node's dominator. Stands in for petgraph's `usize::MAX`.
const DOM_UNDEFINED : Int = -1

///|
/// The dominance relation for some graph and root, port of petgraph's
/// `algo::dominators::Dominators`.
///
/// `idoms` maps every node reachable from the root to its immediate dominator;
/// the root maps to itself. Query it through `root`, `immediate_dominator`,
/// `dominators`, `strict_dominators` and `immediately_dominated_by`.
pub struct Dominators {
  /// The root node the relation was built from.
  root_node : @graph.NodeId
  /// node -> immediate dominator (the root maps to itself).
  idoms : Map[@graph.NodeId, @graph.NodeId]
} derive(Debug)

///|
/// Get the root node used to construct these dominance relations.
pub fn Dominators::root(self : Dominators) -> @graph.NodeId {
  self.root_node
}

///|
/// Get the immediate dominator of the given node.
///
/// Returns `None` for any node that is not reachable from the root, and for the
/// root itself.
pub fn Dominators::immediate_dominator(
  self : Dominators,
  node : @graph.NodeId,
) -> @graph.NodeId? {
  if node == self.root_node {
    None
  } else {
    self.idoms.get(node)
  }
}

///|
/// Iterate over the given node's strict dominators, walking up the dominator
/// tree from its immediate dominator to the root.
///
/// If the given node is not reachable from the root, then `None` is returned.
pub fn Dominators::strict_dominators(
  self : Dominators,
  node : @graph.NodeId,
) -> Iter[@graph.NodeId]? {
  if self.idoms.contains(node) {
    Some(self.walk_dominators(self.immediate_dominator(node)))
  } else {
    None
  }
}

///|
/// Iterate over all of the given node's dominators (including the given node
/// itself).
///
/// If the given node is not reachable from the root, then `None` is returned.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 -> 1 -> 2: every node dominates its successors.
///   let g = @graph.from_edges([(0, 1), (1, 2)])
///   let doms = @algo.simple_fast(g, @graph.NodeId::new(0))
///   guard doms.dominators(@graph.NodeId::new(2)) is Some(it) else {
///     fail("node 2 is reachable")
///   }
///   debug_inspect([ for n in it => n.index() ], content="[2, 1, 0]")
/// }
/// ```
pub fn Dominators::dominators(
  self : Dominators,
  node : @graph.NodeId,
) -> Iter[@graph.NodeId]? {
  if self.idoms.contains(node) {
    Some(self.walk_dominators(Some(node)))
  } else {
    None
  }
}

///|
/// Iterate over all nodes immediately dominated by the given node (not
/// including the given node itself).
///
/// petgraph iterates a `HashMap` here, so its order is arbitrary; MoonBit's
/// `Map` preserves insertion order, so the nodes come out in the order the
/// dominator relation was built (postorder of the root's DFS tree).
pub fn Dominators::immediately_dominated_by(
  self : Dominators,
  node : @graph.NodeId,
) -> Iter[@graph.NodeId] {
  // The root node dominates itself, but it should not be included in the
  // results.
  self.idoms
  .iter()
  .filter(entry => entry.1 == node && entry.0 != entry.1)
  .map(entry => entry.0)
}

///|
/// Shared lazy walk up the dominator tree, starting at `start` and following
/// immediate dominators until the root has been yielded.
fn Dominators::walk_dominators(
  self : Dominators,
  start : @graph.NodeId?,
) -> Iter[@graph.NodeId] {
  let mut node = start
  Iter::new(() => {
    match node {
      None => None
      Some(next) => {
        node = self.immediate_dominator(next)
        Some(next)
      }
    }
  })
}

///|
/// This is an implementation of the engineered ["Simple, Fast Dominance
/// Algorithm"][0] discovered by Cooper et al., port of petgraph's
/// `algo::dominators::simple_fast`.
///
/// This algorithm is **O(|V|^2)** where V is the set of nodes, and therefore has
/// slower theoretical running time than the Lengauer-Tarjan algorithm (which is
/// **O(|E| log |V|)**). However, Cooper et al found it to be faster in practice
/// on control flow graphs of up to ~30,000 nodes.
///
/// Only nodes reachable from `root` take part in the relation; unreachable nodes
/// have no immediate dominator and are absent from `dominators` /
/// `strict_dominators`.
///
/// # Complexity
/// * Time complexity: **O(|V|^2)**.
/// * Auxiliary space: **O(|V| + |E|)**.
///
/// [0]: http://www.hipersoft.rice.edu/grads/publications/dom14.pdf
pub fn[G : @graph.NeighborSource] simple_fast(
  graph : G,
  root : @graph.NodeId,
) -> Dominators {
  let (post_order, predecessor_sets) = simple_fast_post_order(graph, root)
  let length = post_order.length()

  // From here on out we use indices into `post_order` instead of actual
  // `NodeId`s wherever possible; that is what makes the fixpoint loop cheap.
  let node_to_post_order_idx : Map[@graph.NodeId, Int] = Map([])
  for idx, node in post_order {
    node_to_post_order_idx[node] = idx
  }
  let idx_to_predecessor_vec = predecessor_sets_to_idx_vecs(
    post_order, node_to_post_order_idx, predecessor_sets,
  )
  let dominators = Array::make(length, DOM_UNDEFINED)
  if length > 0 {
    // The root is the last element of the postorder and dominates itself.
    dominators[length - 1] = length - 1
  }
  let mut changed = true
  while changed {
    changed = false
    // Iterate in reverse post order, skipping the root.
    for k in 0..<(length - 1) {
      let idx = length - 2 - k
      // Take the intersection of every predecessor's dominator set; that is the
      // current best guess at the immediate dominator for this node.
      let mut new_idom_idx = DOM_UNDEFINED
      for predecessor_idx in idx_to_predecessor_vec[idx] {
        if dominators[predecessor_idx] == DOM_UNDEFINED {
          continue
        }
        if new_idom_idx == DOM_UNDEFINED {
          new_idom_idx = predecessor_idx
        } else {
          new_idom_idx = dominators_intersect(
            dominators, new_idom_idx, predecessor_idx,
          )
        }
      }
      // Because the root is initialized to dominate itself, and is the first
      // node in every path, a reachable node always has such a predecessor.
      if new_idom_idx != DOM_UNDEFINED && new_idom_idx != dominators[idx] {
        dominators[idx] = new_idom_idx
        changed = true
      }
    }
  }

  // All done! Translate the indices back into proper `NodeId`s.
  let idoms : Map[@graph.NodeId, @graph.NodeId] = Map([])
  for idx, dom_idx in dominators {
    if dom_idx != DOM_UNDEFINED {
      idoms[post_order[idx]] = post_order[dom_idx]
    }
  }
  { root_node: root, idoms }
}

///|
/// Walk two fingers up the partially built dominator tree until they meet; the
/// meeting point is the nearest common dominator of both.
fn dominators_intersect(
  dominators : Array[Int],
  finger1 : Int,
  finger2 : Int,
) -> Int {
  for f1 = finger1, f2 = finger2 {
    if f1 < f2 {
      continue dominators[f1], f2
    } else if f1 > f2 {
      continue f1, dominators[f2]
    } else {
      break f1
    }
  }
}

///|
/// Turn the `node -> predecessors` map into a postorder-indexed table of
/// postorder indices, in the order the nodes appear in `post_order`.
fn predecessor_sets_to_idx_vecs(
  post_order : Array[@graph.NodeId],
  node_to_post_order_idx : Map[@graph.NodeId, Int],
  predecessor_sets : Map[@graph.NodeId, Map[@graph.NodeId, Unit]],
) -> Array[Array[Int]] {
  let out = []
  for node in post_order {
    let predecessors : Array[Int] = []
    if predecessor_sets.get(node) is Some(set) {
      for p, _ in set {
        // Every predecessor was itself emitted by the postorder walk.
        guard node_to_post_order_idx.get(p) is Some(idx) else { continue }
        predecessors.push(idx)
      }
    }
    out.push(predecessors)
  }
  out
}

///|
/// Collect the DFS postorder from `root` together with the predecessor set of
/// every node visited along the way.
///
/// The inner `Map[NodeId, Unit]` plays the role of petgraph's `HashSet`, so
/// parallel edges contribute a single predecessor.
fn[G : @graph.NeighborSource] simple_fast_post_order(
  graph : G,
  root : @graph.NodeId,
) -> (Array[@graph.NodeId], Map[@graph.NodeId, Map[@graph.NodeId, Unit]]) {
  let post_order = []
  let predecessor_sets : Map[@graph.NodeId, Map[@graph.NodeId, Unit]] = Map([])
  let dfs = @visit.DfsPostOrder::new(graph, root)
  while dfs.next(graph) is Some(node) {
    post_order.push(node)
    for successor in graph.neighbors_directed(node, Outgoing) {
      if predecessor_sets.get(successor) is Some(set) {
        set[node] = ()
      } else {
        let set : Map[@graph.NodeId, Unit] = Map([])
        set[node] = ()
        predecessor_sets[successor] = set
      }
    }
  }
  (post_order, predecessor_sets)
}
