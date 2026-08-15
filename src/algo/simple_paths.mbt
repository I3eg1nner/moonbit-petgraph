///|
/// The mutable state shared by the two simple-path walks: the ordered set of
/// visited nodes (petgraph's `IndexSet`) and the DFS stack of not-yet-consumed
/// child lists (petgraph's `Vec` of neighbor iterators).
///
/// `on_path` is a dense membership bitmap indexed by `NodeId::index()`, so
/// `contains` is O(1) like the `IndexSet` lookup it replaces. petgraph's
/// neighbor iterators are lazy; here each child list is materialized once into
/// an array with a cursor, which is the closest MoonBit equivalent (an `Iter`
/// cannot be advanced element-by-element).
priv struct SimplePathWalk {
  visited : Array[@graph.NodeId]
  on_path : Array[Bool]
  stack_children : Array[Array[@graph.NodeId]]
  stack_pos : Array[Int]
}

///|
/// Start a walk at `from`, with `from` already on the path and its outgoing
/// neighbors pushed as the first frame.
fn[N, E] SimplePathWalk::new(
  g : @graph.Graph[N, E],
  from : @graph.NodeId,
) -> SimplePathWalk {
  let walk = {
    visited: [],
    on_path: Array::make(g.node_count(), false),
    stack_children: [],
    stack_pos: [],
  }
  walk.push_visited(from)
  walk.push_frame(g, from)
  walk
}

///|
/// Whether `node` is currently on the path being explored.
fn SimplePathWalk::contains(
  self : SimplePathWalk,
  node : @graph.NodeId,
) -> Bool {
  let i = node.index()
  i >= 0 && i < self.on_path.length() && self.on_path[i]
}

///|
/// Append `node` to the visited path (`IndexSet::insert`).
fn SimplePathWalk::push_visited(
  self : SimplePathWalk,
  node : @graph.NodeId,
) -> Unit {
  self.visited.push(node)
  let i = node.index()
  while self.on_path.length() <= i {
    self.on_path.push(false)
  }
  self.on_path[i] = true
}

///|
/// Drop the last visited node (`IndexSet::pop`).
fn SimplePathWalk::pop_visited(self : SimplePathWalk) -> Unit {
  if self.visited.pop() is Some(node) {
    self.on_path[node.index()] = false
  }
}

///|
/// Push the outgoing neighbors of `node` as a new stack frame.
fn[N, E] SimplePathWalk::push_frame(
  self : SimplePathWalk,
  g : @graph.Graph[N, E],
  node : @graph.NodeId,
) -> Unit {
  self.stack_children.push(g.neighbors_directed(node, Outgoing).to_array())
  self.stack_pos.push(0)
}

///|
/// Pop the current stack frame (`stack.pop()`).
fn SimplePathWalk::pop_frame(self : SimplePathWalk) -> Unit {
  self.stack_children.pop() |> ignore
  self.stack_pos.pop() |> ignore
}

///|
/// The current path extended by `last`: the yielded value.
fn SimplePathWalk::path_to(
  self : SimplePathWalk,
  last : @graph.NodeId,
) -> Array[@graph.NodeId] {
  let path = [..self.visited]
  path.push(last)
  path
}

///|
/// Calculate all simple paths with specified constraints from node `from` to
/// node `to`.
///
/// A simple path is a path without repeating nodes. The number of simple paths
/// between a given pair of vertices can grow exponentially, reaching `O(|V|!)`
/// on complete graphs, so on a large graph consider consuming only a prefix of
/// the returned iterator. Note also that this algorithm does not check that a
/// path exists between `from` and `to` at all.
///
/// Port of petgraph's `algo::all_simple_paths`, itself adapted from NetworkX.
/// `min_intermediate_nodes` / `max_intermediate_nodes` bound the number of
/// nodes strictly between `from` and `to`; when `max_intermediate_nodes` is
/// absent the bound is the graph's order. Paths are produced lazily, in the
/// same DFS order as petgraph.
///
/// Time complexity: **O(k|V| + k|E|)** for the first **k** paths.
/// Auxiliary space: **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([
///     (0, 1),
///     (1, 2),
///     (2, 3),
///     (1, 3),
///   ])
///   let paths = @algo.all_simple_paths(
///     g,
///     @graph.NodeId::new(0),
///     @graph.NodeId::new(3),
///     0,
///   )
///   let out = [ for p in paths => [ for n in p => n.index() ] ]
///   debug_inspect(out, content="[[0, 1, 3], [0, 1, 2, 3]]")
/// }
/// ```
pub fn[N, E] all_simple_paths(
  g : @graph.Graph[N, E],
  from : @graph.NodeId,
  to : @graph.NodeId,
  min_intermediate_nodes : Int,
  max_intermediate_nodes? : Int,
) -> Iter[Array[@graph.NodeId]] {
  // How many nodes are allowed in a simple path *up to* the target node; it is
  // the min/max allowed path length minus one, which is what the lookahead
  // below wants to compare against.
  let max_length = match max_intermediate_nodes {
    Some(l) => l + 1
    None => g.node_count() - 1
  }
  let min_length = min_intermediate_nodes + 1
  let walk = SimplePathWalk::new(g, from)
  Iter::new(fn() {
    while walk.stack_children.length() > 0 {
      let top = walk.stack_children.length() - 1
      let children = walk.stack_children[top]
      let pos = walk.stack_pos[top]
      if pos < children.length() {
        walk.stack_pos[top] = pos + 1
        let child = children[pos]
        if walk.contains(child) {
          continue
        }
        if walk.visited.length() < max_length {
          if child == to {
            if walk.visited.length() >= min_length {
              return Some(walk.path_to(to))
            }
          } else {
            walk.push_visited(child)
            walk.push_frame(g, child)
          }
        } else {
          // At the length limit: only a direct hop to `to` can still extend
          // this path. petgraph probes the *rest* of the child list with
          // `Iterator::any`, which consumes it up to the match; reproduce that
          // by advancing the cursor.
          let mut reaches_target = child == to
          if !reaches_target {
            let mut i = walk.stack_pos[top]
            while i < children.length() {
              let v = children[i]
              i = i + 1
              if v == to && !walk.contains(v) {
                reaches_target = true
                break
              }
            }
            walk.stack_pos[top] = i
          }
          if reaches_target && walk.visited.length() >= min_length {
            return Some(walk.path_to(to))
          }
          walk.pop_frame()
          walk.pop_visited()
        }
      } else {
        walk.pop_frame()
        walk.pop_visited()
      }
    }
    None
  })
}

///|
/// Calculate all simple paths from a source node to any of several target
/// nodes.
///
/// A variant of `all_simple_paths` that accepts a collection of target nodes
/// instead of a single one. A path is yielded as soon as it reaches any node in
/// `to`.
///
/// This provides significant gains on graphs where paths share long initial
/// segments (trees and DAGs), since a single traversal serves every target.
/// Conversely, in dense graphs where paths diverge quickly, repeated calls to
/// `all_simple_paths` may be faster.
///
/// Port of petgraph's `algo::all_simple_paths_multi`. petgraph takes a
/// `&HashSet`; here `to` is an `Array[NodeId]` whose membership is turned into
/// a dense bitmap internally, so duplicates are harmless.
///
/// Time complexity: **O(k|V| + k|E|)** for the first **k** paths.
/// Auxiliary space: **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges_undirected([
///     (0, 1),
///     (1, 2),
///     (2, 3),
///     (2, 4),
///   ])
///   let paths = @algo.all_simple_paths_multi(
///     g,
///     @graph.NodeId::new(0),
///     [@graph.NodeId::new(3), @graph.NodeId::new(4)],
///     0,
///   )
///   let out = [ for p in paths => [ for n in p => n.index() ] ]
///   debug_inspect(out, content="[[0, 1, 2, 4], [0, 1, 2, 3]]")
/// }
/// ```
pub fn[N, E] all_simple_paths_multi(
  g : @graph.Graph[N, E],
  from : @graph.NodeId,
  to : Array[@graph.NodeId],
  min_intermediate_nodes : Int,
  max_intermediate_nodes? : Int,
) -> Iter[Array[@graph.NodeId]] {
  // Unlike `all_simple_paths` these bounds count the endpoints too, matching
  // petgraph's `+ 2` / `node_count()`.
  let max_nodes = match max_intermediate_nodes {
    Some(l) => l + 2
    None => g.node_count()
  }
  let min_nodes = min_intermediate_nodes + 2
  let is_target = Array::make(g.node_count(), false)
  for t in to {
    let i = t.index()
    while is_target.length() <= i {
      is_target.push(false)
    }
    is_target[i] = true
  }
  let walk = SimplePathWalk::new(g, from)
  Iter::new(fn() {
    while walk.stack_children.length() > 0 {
      let top = walk.stack_children.length() - 1
      let children = walk.stack_children[top]
      let pos = walk.stack_pos[top]
      if pos < children.length() {
        walk.stack_pos[top] = pos + 1
        let child = children[pos]
        if walk.contains(child) {
          continue
        }
        let current_nodes = walk.visited.length()
        // Reaching any target yields a path, but the search still continues
        // through `child` if other targets remain unexplored.
        let mut valid_path : Array[@graph.NodeId]? = None
        if is_target[child.index()] && current_nodes + 1 >= min_nodes {
          valid_path = Some(walk.path_to(child))
        }
        let mut more_targets = false
        for t in to {
          if t != child && !walk.contains(t) {
            more_targets = true
            break
          }
        }
        if current_nodes < max_nodes && more_targets {
          walk.push_visited(child)
          walk.push_frame(g, child)
        }
        if valid_path is Some(_) {
          return valid_path
        }
      } else {
        walk.pop_frame()
        walk.pop_visited()
      }
    }
    None
  })
}
