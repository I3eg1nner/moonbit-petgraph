///|
/// Dijkstra's shortest-path algorithm.
///
/// Computes the length of the shortest path from `start` to every reachable
/// node, using non-negative edge costs returned by `edge_cost`.
///
/// If `goal` is `Some(g)`, the search terminates once `g`'s final cost has been
/// settled (popped from the queue). The returned map still contains every node
/// whose distance was settled before that point.
///
/// Returns a `Map` from `NodeId` to the shortest distance from `start`. Nodes
/// that are unreachable from `start` are absent from the map.
///
/// This is a direct port of petgraph's `algo::dijkstra`. The priority queue is a
/// binary max-heap of `MinScored` entries, whose reversed ordering on the score
/// makes it behave as a min-heap (smallest tentative distance popped first).
pub fn[N, E, K : Measure] dijkstra(
  g : @graph.Graph[N, E],
  start~ : @graph.NodeId,
  goal? : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> Map[@graph.NodeId, K] {
  let visited = @visit.VisitMap::new(g.node_count())
  let scores : Map[@graph.NodeId, K] = Map([])
  let visit_next : @priority_queue.PriorityQueue[MinScored[K, @graph.NodeId]] = PriorityQueue([],
  )
  let zero = K::zero()
  scores[start] = zero
  visit_next.push(MinScored(zero, start))
  while visit_next.pop() is Some(MinScored(node_score, node)) {
    if visited.is_visited(node) {
      continue
    }
    if goal is Some(target) && node == target {
      break
    }
    // `edges` (not `edges_directed`) is what makes this correct on undirected
    // graphs: it normalizes each incident edge so `target` is the endpoint away
    // from `node`, exactly like petgraph's `Edges`/`EdgeRef::target`. Reading
    // the stored `dst` instead would walk back into `node` for any undirected
    // edge that happens to be stored as `(other, node)`.
    for eref in g.edges(node) {
      let next = eref.target
      if visited.is_visited(next) {
        continue
      }
      let next_score = node_score.add(edge_cost(eref.id))
      match scores.get(next) {
        Some(cur) =>
          if next_score.compare(cur) < 0 {
            scores[next] = next_score
            visit_next.push(MinScored(next_score, next))
          }
        None => {
          scores[next] = next_score
          visit_next.push(MinScored(next_score, next))
        }
      }
    }
    visited.visit(node) |> ignore
  }
  scores
}
