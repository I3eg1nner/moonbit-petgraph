///|
/// The smaller of `a` and `b`.
///
/// Port of the `min` helper of petgraph's `algo::maximum_flow::dinics`. Upstream
/// only requires `PartialOrd` and panics on incomparable values; our `Measure`
/// bound provides a total order, so no panic is possible.
fn[K : BoundedMeasure] flow_min(a : K, b : K) -> K {
  if Measure::compare(a, b) < 0 {
    a
  } else {
    b
  }
}

///|
/// BFS labelling every vertex with its distance from `source` in the residual
/// network, considering only edges with positive residual capacity.
///
/// The source is labelled `1` and unreachable vertices keep the label `0`.
/// `level_edges[v]` collects the edges connecting `v` to its neighbours on the
/// next level.
///
/// Port of `build_level_graph` in petgraph's `algo::maximum_flow::dinics`. Note
/// that (as upstream) `level_edges` is only cleared for vertices that are
/// actually dequeued; the destination is never enqueued, and vertices outside
/// the level graph are never expanded by the DFS, so stale entries are unused.
fn[N, E, K : BoundedMeasure] build_level_graph(
  g : @graph.Graph[N, E],
  source : @graph.NodeId,
  destination : @graph.NodeId,
  flows : Array[K],
  level_edges : Array[Array[@graph.EdgeId]],
  edge_cost : (@graph.EdgeId) -> K,
) -> Array[Int] {
  let level_graph = Array::make(g.node_count(), 0)
  let bfs_queue : @deque.Deque[@graph.NodeId] = @deque.Deque([])
  bfs_queue.push_back(source)
  level_graph[source.index()] = 1
  let zero = Measure::zero()
  while bfs_queue.pop_front() is Some(vertex) {
    let vertex_index = vertex.index()
    level_edges[vertex_index].clear()
    for edge in incident_edges(g, vertex) {
      let next_vertex = edge_other_endpoint(g, edge, vertex)
      let residual_cap = flow_residual_capacity(
        g,
        edge,
        next_vertex,
        flows[edge.index()],
        edge_cost,
      )
      if Measure::compare(residual_cap, zero) == 0 {
        continue
      }
      let next_index = next_vertex.index()
      if level_graph[next_index] == 0 {
        level_graph[next_index] = level_graph[vertex_index] + 1
        level_edges[vertex_index].push(edge)
        if next_vertex != destination {
          bfs_queue.push_back(next_vertex)
        }
      } else if level_graph[next_index] == level_graph[vertex_index] + 1 {
        level_edges[vertex_index].push(edge)
      }
    }
  }
  level_graph
}

///|
/// DFS through the level graph looking for an augmenting path from `source` to
/// `destination`, recording it in `edge_to`.
///
/// Edges whose residual capacity has dropped to zero are swap-removed from
/// `level_edges` so later searches in the same phase skip them.
///
/// Port of `find_augmenting_path` in petgraph's `algo::maximum_flow::dinics`.
fn[N, E, K : BoundedMeasure] find_augmenting_path(
  g : @graph.Graph[N, E],
  source : @graph.NodeId,
  destination : @graph.NodeId,
  flows : Array[K],
  level_edges : Array[Array[@graph.EdgeId]],
  visited : @visit.VisitMap,
  edge_to : Array[@graph.EdgeId?],
  edge_cost : (@graph.EdgeId) -> K,
) -> Bool {
  visited.reset()
  let level_edges_i = Array::make(level_edges.length(), 0)
  let dfs_stack : Array[@graph.NodeId] = []
  dfs_stack.push(source)
  visited.visit(source) |> ignore
  let zero = Measure::zero()
  while dfs_stack.last() is Some(vertex) {
    let vertex_index = vertex.index()
    let mut found_next = false
    while level_edges_i[vertex_index] < level_edges[vertex_index].length() {
      let curr = level_edges_i[vertex_index]
      let edge = level_edges[vertex_index][curr]
      let next_vertex = edge_other_endpoint(g, edge, vertex)
      let residual_cap = flow_residual_capacity(
        g,
        edge,
        next_vertex,
        flows[edge.index()],
        edge_cost,
      )
      if Measure::compare(residual_cap, zero) == 0 {
        // swap_remove(curr): the saturated edge is gone for this phase.
        let edges = level_edges[vertex_index]
        edges[curr] = edges[edges.length() - 1]
        edges.pop() |> ignore
        continue
      }
      if !visited.is_visited(next_vertex) {
        edge_to[next_vertex.index()] = Some(edge)
        if destination == next_vertex {
          return true
        }
        dfs_stack.push(next_vertex)
        visited.visit(next_vertex) |> ignore
        found_next = true
        break
      }
      level_edges_i[vertex_index] = level_edges_i[vertex_index] + 1
    }
    if !found_next {
      dfs_stack.pop() |> ignore
    }
  }
  false
}

///|
/// Saturate the current level graph: repeatedly find an augmenting path in it
/// and push its bottleneck capacity, until no such path remains.
///
/// Returns the total flow pushed during this phase. Port of
/// `find_blocking_flow` in petgraph's `algo::maximum_flow::dinics`.
fn[N, E, K : BoundedMeasure] find_blocking_flow(
  g : @graph.Graph[N, E],
  source : @graph.NodeId,
  destination : @graph.NodeId,
  flows : Array[K],
  level_edges : Array[Array[@graph.EdgeId]],
  visited : @visit.VisitMap,
  edge_cost : (@graph.EdgeId) -> K,
) -> K {
  let mut flow_increase = Measure::zero()
  let edge_to : Array[@graph.EdgeId?] = Array::make(g.node_count(), None)
  while find_augmenting_path(
          g, source, destination, flows, level_edges, visited, edge_to, edge_cost,
        ) {
    // Find the bottleneck capacity of the path.
    let mut path_flow = K::max_value()
    let mut vertex = destination
    while edge_to[vertex.index()] is Some(edge) {
      let residual_cap = flow_residual_capacity(
        g,
        edge,
        vertex,
        flows[edge.index()],
        edge_cost,
      )
      path_flow = flow_min(path_flow, residual_cap)
      vertex = edge_other_endpoint(g, edge, vertex)
    }
    // Update the flow of each edge along the discovered path.
    vertex = destination
    while edge_to[vertex.index()] is Some(edge) {
      flows[edge.index()] = flow_adjust_residual(
        g,
        edge,
        vertex,
        flows[edge.index()],
        path_flow,
      )
      vertex = edge_other_endpoint(g, edge, vertex)
    }
    flow_increase = Measure::add(flow_increase, path_flow)
  }
  flow_increase
}

///|
/// [Dinic's (or Dinitz's) algorithm][dinics]: computes the maximum flow from
/// `source` to `destination` in a weighted directed graph by building successive
/// level graphs with a breadth-first search and finding a blocking flow within
/// each of them with depth-first searches.
///
/// # Arguments
/// * `g`: a directed graph with non-negative edge weights ("flow capacities").
/// * `source`: the node where flow originates.
/// * `destination`: the node where flow terminates.
/// * `edge_cost`: the capacity of each edge.
///
/// # Returns
/// A pair of
/// * `K`: the computed maximum flow;
/// * `Array[K]`: the flow of each edge, indexed by `EdgeId::index()`.
///
/// # Complexity
/// * Time: **O(|V|²|E|)** in general, auxiliary space **O(|V| + |E|)**.
///
/// Direct port of petgraph's `algo::maximum_flow::dinics`. It computes the same
/// maximum flow value as `ford_fulkerson` (the per-edge flows may differ, since
/// a maximum flow is generally not unique).
///
/// [dinics]: https://en.wikipedia.org/wiki/Dinic%27s_algorithm
pub fn[N, E, K : BoundedMeasure] dinics(
  g : @graph.Graph[N, E],
  source~ : @graph.NodeId,
  destination~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> (K, Array[K]) {
  let mut max_flow = Measure::zero()
  let flows : Array[K] = Array::make(g.edge_count(), Measure::zero())
  let visited = @visit.VisitMap::new(g.node_count())
  let level_edges : Array[Array[@graph.EdgeId]] = Array::makei(g.node_count(), _ => {
    []
  })
  let dest_index = destination.index()
  while build_level_graph(g, source, destination, flows, level_edges, edge_cost)[dest_index] >
        0 {
    let flow_increase = find_blocking_flow(
      g, source, destination, flows, level_edges, visited, edge_cost,
    )
    max_flow = Measure::add(max_flow, flow_increase)
  }
  (max_flow, flows)
}
