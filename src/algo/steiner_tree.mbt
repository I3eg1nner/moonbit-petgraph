///|
/// All-pairs shortest paths with predecessor tracking, used by `steiner_tree`.
///
/// Returns `(dist, prev)` where `dist[i][j]` is the length of a shortest path
/// from `i` to `j` (`K::max_value()` when there is none) and `prev[i][j]` is the
/// penultimate node on that path (`prev[i][i]` is `Some(i)`).
///
/// This is a port of petgraph's `algo::floyd_warshall::floyd_warshall_path`,
/// inlined here because `steiner_tree` is the only user in this package: it
/// needs both the metric closure lengths (which petgraph computes with
/// `dijkstra`) and the shortest paths themselves, and the two must agree.
/// Undirected graphs are handled as upstream does, by initializing both
/// directions of every edge.
fn[N, E, K : BoundedMeasure] steiner_shortest_paths(
  g : @graph.Graph[N, E],
  edge_cost : (@graph.EdgeId) -> K,
) -> (Array[Array[K]], Array[Array[Int?]]) {
  let n = g.node_count()
  let dist : Array[Array[K]] = Array::makei(n, _ => {
    Array::make(n, K::max_value())
  })
  let prev : Array[Array[Int?]] = Array::makei(n, _ => Array::make(n, None))
  let directed = g.is_directed()
  // Initialize distances and predecessors for edges.
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((s, t)) else { continue }
    let source = s.index()
    let target = t.index()
    let cost = edge_cost(edge)
    if Measure::compare(dist[source][target], cost) > 0 {
      dist[source][target] = cost
      prev[source][target] = Some(source)
      if !directed {
        dist[target][source] = cost
        prev[target][source] = Some(target)
      }
    }
  }
  // The distance of each node to itself is zero.
  for i in 0..<n {
    dist[i][i] = Measure::zero()
    prev[i][i] = Some(i)
  }
  for k in 0..<n {
    for i in 0..<n {
      for j in 0..<n {
        // `checked_add` reports the overflow that upstream detects with
        // `overflowing_add`, i.e. a path through an unreachable node.
        if dist[i][k].checked_add(dist[k][j]) is Some(result) &&
          Measure::compare(dist[i][j], result) > 0 {
          dist[i][j] = result
          prev[i][j] = prev[k][j]
        }
      }
    }
  }
  (dist, prev)
}

///|
/// [Steiner tree][1] approximation.
///
/// Computes a Steiner tree of an undirected connected graph for a set of
/// terminal nodes via [Kou's algorithm][2]:
///
/// 1. build the metric closure of the terminals (a complete graph on the
///    terminals whose edge weights are shortest-path lengths in `g`);
/// 2. take a minimum spanning tree of that closure (with Kruskal's
///    `min_spanning_tree`);
/// 3. expand every closure edge back into a shortest path of `g`;
/// 4. prune non-terminal leaves until none is left.
///
/// # Arguments
/// * `g`: the undirected graph in which to find the Steiner tree.
/// * `terminals`: the nodes that must be connected by the tree.
/// * `edge_cost`: the weight of each edge; weights must be non-negative.
///
/// # Returns
/// The edges of the Steiner tree, in increasing `EdgeId` order. (Petgraph
/// returns a `StableGraph` holding the retained nodes and edges; this port
/// returns the retained edge set of `g`, matching the return shape of
/// `min_spanning_tree`. The retained node set is exactly the set of endpoints of
/// those edges.)
///
/// # Complexity
/// * Time: **O(|V|³)**, dominated by the all-pairs shortest paths.
///
/// Port of petgraph's `algo::steiner_tree::steiner_tree`, with the same
/// implementation details as the NetworkX implementation it follows.
///
/// [1]: https://en.wikipedia.org/wiki/Steiner_tree_problem
/// [2]: https://doi.org/10.1007/BF00288961
pub fn[N, E, K : BoundedMeasure] steiner_tree(
  g : @graph.Graph[N, E],
  terminals : Array[@graph.NodeId],
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Array[@graph.EdgeId] {
  let n = g.node_count()
  let result : Array[@graph.EdgeId] = []
  guard n > 0 && terminals.length() > 1 else { return result }
  let (dist, prev) = steiner_shortest_paths(g, edge_cost)

  // Metric closure: a complete graph on the terminals, weighted by shortest
  // path lengths.
  let closure : @graph.Graph[Unit, K] = @graph.Graph::new_undirected()
  for _i in 0..<n {
    closure.add_node(()) |> ignore
  }
  for i in 0..<terminals.length() {
    for j in (i + 1)..<terminals.length() {
      let a = terminals[i]
      let b = terminals[j]
      closure.add_edge(a, b, dist[a.index()][b.index()]) |> ignore
    }
  }
  let minimum_spanning = min_spanning_tree(closure, edge_cost=e => {
    match closure.edge_weight(e) {
      Some(w) => w
      None => abort("Missing metric closure weight")
    }
  })

  // Expand each spanning-tree edge of the closure back into a shortest path of
  // `g`, collecting the nodes and (undirected) node pairs it walks through.
  let retained_nodes = Array::make(n, false)
  let retained_pairs : Array[Array[Bool]] = Array::makei(n, _ => {
    Array::make(n, false)
  })
  for edge in minimum_spanning {
    guard closure.edge_endpoints(edge) is Some((s, t)) else { continue }
    let source = s.index()
    let mut current = t.index()
    while current != source {
      guard prev[source][current] is Some(prev_node) else { break }
      retained_nodes[prev_node] = true
      retained_nodes[current] = true
      retained_pairs[prev_node][current] = true
      current = prev_node
    }
  }

  // Keep the edges of `g` that realize one of those pairs.
  let kept = Array::make(g.edge_count(), false)
  let neighbors : Array[Array[Int]] = Array::makei(n, _ => [])
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((s, t)) else { continue }
    let a = s.index()
    let b = t.index()
    if retained_pairs[a][b] || retained_pairs[b][a] {
      kept[edge.index()] = true
      if !neighbors[a].contains(b) {
        neighbors[a].push(b)
      }
      if !neighbors[b].contains(a) {
        neighbors[b].push(a)
      }
    }
  }

  // Prune non-terminal leaves, in rounds, until no leaf is left (petgraph's
  // `non_terminal_leaves`). A node is a leaf when exactly one of its distinct
  // neighbors is still present.
  let is_terminal = Array::make(n, false)
  for t in terminals {
    is_terminal[t.index()] = true
  }
  let removed = Array::make(n, false)
  for ;; {
    let leaves : Array[Int] = []
    for v in 0..<n {
      if retained_nodes[v] && !is_terminal[v] && !removed[v] {
        let mut degree = 0
        for u in neighbors[v] {
          if !removed[u] {
            degree = degree + 1
          }
        }
        if degree == 1 {
          leaves.push(v)
        }
      }
    }
    if leaves.is_empty() {
      break
    }
    for v in leaves {
      removed[v] = true
    }
  }
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((s, t)) else { continue }
    if kept[edge.index()] && !removed[s.index()] && !removed[t.index()] {
      result.push(edge)
    }
  }
  result
}
