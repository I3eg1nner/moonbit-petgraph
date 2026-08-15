///|
/// The endpoint of edge `e` opposite to `from`, or `None` if `e` does not
/// exist.
///
/// This is the MoonBit stand-in for petgraph's `EdgeRef::target()` as seen from
/// the node whose edge list is being walked. petgraph's `Edges` iterator swaps
/// the two endpoints of an undirected edge so that `source()` is always the
/// node you asked about; storing only `(src, dst)` we recover the same thing by
/// picking whichever endpoint is not `from`. For a directed graph walked with
/// `Outgoing` this is just `dst` (and with `Incoming`, just `src`), and a
/// self-loop correctly yields `from` itself.
fn[N, E] edge_far_endpoint(
  g : @graph.Graph[N, E],
  e : @graph.EdgeId,
  from : @graph.NodeId,
) -> @graph.NodeId? {
  match g.edge_endpoints(e) {
    Some((src, dst)) => Some(if src == from { dst } else { src })
    None => None
  }
}

///|
/// Shortest Path Faster Algorithm: a queue-based Bellman-Ford.
///
/// Computes the shortest distances from `source` to every other node in a graph
/// whose edge costs may be positive *or* negative, provided there is no
/// negative cycle. Raises `NegativeCycle` if one is found.
///
/// Direct port of petgraph's `algo::spfa`. Instead of relaxing *every* edge
/// `|V| - 1` times like `bellman_ford`, only the nodes whose tentative distance
/// just improved are queued for re-examination; a node that is dequeued more
/// than `|V|` times can only be on a negative cycle. Internally distances start
/// at `BoundedMeasure::max_value()` and relaxation goes through `checked_add`,
/// exactly as upstream.
///
/// Like petgraph — where `spfa` returns the very same `Paths` struct as
/// `bellman_ford` — the result is a `BellmanFordPaths[K]`, so "unreachable" is
/// reported as `None` rather than as the `max_value()` sentinel and the two
/// algorithms are directly comparable.
///
/// Time complexity **O(|V||E|)** worst case (**O(|E|)** on average), auxiliary
/// space **O(|V|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 ->2-> 1 ->-1-> 2, plus a dearer direct edge 0 ->4-> 2.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   let n0 = g.add_node(0)
///   let n1 = g.add_node(1)
///   let n2 = g.add_node(2)
///   let _ = g.add_edge(n0, n1, 2)
///   let _ = g.add_edge(n1, n2, -1)
///   let _ = g.add_edge(n0, n2, 4)
///   let paths = @algo.spfa(g, source=n0, edge_cost=e => g.edge_weight(e).unwrap())
///   debug_inspect(paths.distances[n2.index()], content="Some(1)")
/// }
/// ```
pub fn[N, E, K : BoundedMeasure] spfa(
  g : @graph.Graph[N, E],
  source~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> BellmanFordPaths[K] raise NegativeCycle {
  let n = g.node_count()
  let inf = K::max_value()
  let dist : Array[K] = Array::make(n, inf)
  let predecessors : Array[@graph.NodeId?] = Array::make(n, None)
  dist[source.index()] = Measure::zero()

  // Queue of vertices capable of relaxing the distances found so far.
  let queue : @deque.Deque[@graph.NodeId] = Deque([])
  let in_queue : Array[Bool] = Array::make(n, false)
  queue.push_back(source)
  in_queue[source.index()] = true
  spfa_loop(g, dist, Some(predecessors), queue, in_queue, edge_cost)
  // Translate the `max_value()` sentinel back into this package's "infinity is
  // absent" convention, shared with `bellman_ford`.
  let distances : Array[K?] = [
    for d in dist => if Measure::compare(d, inf) == 0 { None } else { Some(d) }
  ]
  { distances, predecessors }
}

///|
/// The main loop of SPFA, shared with `johnson`'s reweighting pass. Computing
/// predecessors is optional.
///
/// `distances`, `predecessors` and `in_queue` are updated in place; `queue`
/// must already contain at least one source node and `in_queue` must agree
/// with it. Raises `NegativeCycle` as soon as some node has been dequeued
/// `node_count` times, which in a graph without a negative cycle is impossible.
fn[N, E, K : BoundedMeasure] spfa_loop(
  g : @graph.Graph[N, E],
  distances : Array[K],
  predecessors : Array[@graph.NodeId?]?,
  queue : @deque.Deque[@graph.NodeId],
  in_queue : Array[Bool],
  edge_cost : (@graph.EdgeId) -> K,
) -> Unit raise NegativeCycle {
  let n = g.node_count()
  // How many times each vertex has left the queue, to detect negative cycles.
  let visits : Array[Int] = Array::make(n, 0)
  while queue.pop_front() is Some(i) {
    let ii = i.index()
    in_queue[ii] = false
    // Without a negative cycle no vertex can improve the shortest distances
    // more than |V| times.
    if visits[ii] >= n {
      raise NegativeCycle
    }
    visits[ii] = visits[ii] + 1
    for edge in g.edges_directed(i, Outgoing) {
      guard edge_far_endpoint(g, edge, i) is Some(j) else { continue }
      let w = edge_cost(edge)
      guard distances[ii].checked_add(w) is Some(d) else { continue }
      let jj = j.index()
      if Measure::compare(d, distances[jj]) < 0 {
        distances[jj] = d
        if predecessors is Some(p) {
          p[jj] = Some(i)
        }
        if !in_queue[jj] {
          in_queue[jj] = true
          queue.push_back(j)
        }
      }
    }
  }
}
