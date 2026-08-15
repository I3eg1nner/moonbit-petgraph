///|
/// Bidirectional Dijkstra shortest-path search.
///
/// Returns the cost of the shortest path from `start` to `goal`, or `None` if
/// there is none. Edge costs must be non-negative.
///
/// Two Dijkstra searches are advanced in lockstep: a forward one from `start`
/// following `Outgoing` edges, and a backward one from `goal` following
/// `Incoming` edges. Whenever an edge joins the two explored regions, the
/// combined cost becomes a candidate answer; once the two frontiers have
/// together advanced at least as far as the best candidate, that candidate is
/// optimal and is returned. This typically settles about half as many nodes as
/// plain `dijkstra`, which is worthwhile for a single long path in a sparse
/// graph but not when several goals share one source.
///
/// Direct port of petgraph's `algo::bidirectional_dijkstra`, including its
/// lockstep structure (one pop from each heap per iteration, stopping as soon
/// as *either* heap runs dry) and its stopping rule
/// `distance_to_u + distance_to_v >= best_value`. Note the upstream quirk that
/// `start == goal` is not special-cased: the search then looks for the cheapest
/// cycle through that node, and returns `None` when there is none.
///
/// Time complexity **O((|V|+|E|)log(|V|))**, auxiliary space **O(|V|+|E|)**.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 ->1-> 1 ->2-> 2, plus the dearer direct edge 0 ->4-> 2.
///   let g : @graph.Graph[Int, Int] = @graph.Graph::new()
///   let n0 = g.add_node(0)
///   let n1 = g.add_node(1)
///   let n2 = g.add_node(2)
///   let _ = g.add_edge(n0, n1, 1)
///   let _ = g.add_edge(n1, n2, 2)
///   let _ = g.add_edge(n0, n2, 4)
///   let cost = @algo.bidirectional_dijkstra(g, start=n0, goal=n2, edge_cost=e => {
///     g.edge_weight(e).unwrap()
///   })
///   debug_inspect(cost, content="Some(3)")
/// }
/// ```
pub fn[N, E, K : Measure] bidirectional_dijkstra(
  g : @graph.Graph[N, E],
  start~ : @graph.NodeId,
  goal~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> K? {
  let n = g.node_count()
  let zero = K::zero()
  let forward_visited = @visit.VisitMap::new(n)
  let forward_distance : Map[@graph.NodeId, K] = Map([])
  forward_distance[start] = zero
  let backward_visited = @visit.VisitMap::new(n)
  let backward_distance : Map[@graph.NodeId, K] = Map([])
  backward_distance[goal] = zero
  let forward_heap : @priority_queue.PriorityQueue[MinScored[K, @graph.NodeId]] = PriorityQueue([],
  )
  let backward_heap : @priority_queue.PriorityQueue[MinScored[K, @graph.NodeId]] = PriorityQueue([],
  )
  forward_heap.push(MinScored(zero, start))
  backward_heap.push(MinScored(zero, goal))
  let mut best_value : K? = None
  while forward_heap.length() > 0 && backward_heap.length() > 0 {
    guard forward_heap.pop() is Some(MinScored(_, u)) else { break }
    guard backward_heap.pop() is Some(MinScored(_, v)) else { break }
    forward_visited.visit(u) |> ignore
    backward_visited.visit(v) |> ignore
    // Both are present: a node only enters a heap together with its distance.
    guard forward_distance.get(u) is Some(distance_to_u) else { break }
    guard backward_distance.get(v) is Some(distance_to_v) else { break }

    // Expand the forward search by one node.
    for edge in g.edges_directed(u, Outgoing) {
      guard edge_far_endpoint(g, edge, u) is Some(x) else { continue }
      let current_edge_cost = edge_cost(edge)
      if !forward_visited.is_visited(x) {
        let next_score = distance_to_u.add(current_edge_cost)
        match forward_distance.get(x) {
          Some(cur) =>
            if next_score.compare(cur) < 0 {
              forward_distance[x] = next_score
              forward_heap.push(MinScored(next_score, x))
            }
          None => {
            forward_distance[x] = next_score
            forward_heap.push(MinScored(next_score, x))
          }
        }
      }
      // If the backward search already settled `x`, the two halves join here.
      if !backward_visited.is_visited(x) {
        continue
      }
      guard backward_distance.get(x) is Some(backward_x) else { continue }
      let potential_best_value = distance_to_u
        .add(current_edge_cost)
        .add(backward_x)
      let improves_best_value = match best_value {
        None => true
        Some(current_best_value) =>
          potential_best_value.compare(current_best_value) < 0
      }
      if improves_best_value {
        best_value = Some(potential_best_value)
      }
    }

    // Expand the backward search by one node.
    for edge in g.edges_directed(v, Incoming) {
      guard edge_far_endpoint(g, edge, v) is Some(x) else { continue }
      let current_edge_cost = edge_cost(edge)
      if !backward_visited.is_visited(x) {
        let next_score = distance_to_v.add(current_edge_cost)
        match backward_distance.get(x) {
          Some(cur) =>
            if next_score.compare(cur) < 0 {
              backward_distance[x] = next_score
              backward_heap.push(MinScored(next_score, x))
            }
          None => {
            backward_distance[x] = next_score
            backward_heap.push(MinScored(next_score, x))
          }
        }
      }
      if !forward_visited.is_visited(x) {
        continue
      }
      guard forward_distance.get(x) is Some(forward_x) else { continue }
      let potential_best_value = distance_to_v
        .add(current_edge_cost)
        .add(forward_x)
      let improves_best_value = match best_value {
        None => true
        Some(mu) => potential_best_value.compare(mu) < 0
      }
      if improves_best_value {
        best_value = Some(potential_best_value)
      }
    }

    // The frontiers have met and cannot improve on the candidate any more.
    if best_value is Some(bv) &&
      distance_to_u.add(distance_to_v).compare(bv) >= 0 {
      return Some(bv)
    }
  }
  None
}
