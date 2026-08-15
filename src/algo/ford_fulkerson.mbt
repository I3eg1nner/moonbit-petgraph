///|
/// The other endpoint of `edge` relative to `vertex`.
///
/// Port of the `other_endpoint` helper shared by petgraph's maximum-flow
/// modules (`algo::maximum_flow::{ford_fulkerson, dinics}`). Aborts if `vertex`
/// is not an endpoint of `edge`, exactly like the upstream `panic!("Illegal
/// endpoint")`.
fn[N, E] edge_other_endpoint(
  g : @graph.Graph[N, E],
  edge : @graph.EdgeId,
  vertex : @graph.NodeId,
) -> @graph.NodeId {
  guard g.edge_endpoints(edge) is Some((src, dst)) else {
    abort("Illegal edge \{edge.index()}")
  }
  if vertex == src {
    dst
  } else if vertex == dst {
    src
  } else {
    abort("Illegal endpoint \{vertex.index()}")
  }
}

///|
/// The residual capacity of `edge` when it is traversed *towards* `vertex`.
///
/// Port of the `residual_capacity` helper of petgraph's maximum-flow modules:
///
/// * if `vertex` is the edge's source we are walking the edge backwards, and the
///   residual capacity is the flow that can be cancelled, i.e. `flow`;
/// * if `vertex` is the edge's target we are walking it forwards, and the
///   residual capacity is `capacity - flow`.
fn[N, E, K : BoundedMeasure] flow_residual_capacity(
  g : @graph.Graph[N, E],
  edge : @graph.EdgeId,
  vertex : @graph.NodeId,
  flow : K,
  edge_cost : (@graph.EdgeId) -> K,
) -> K {
  guard g.edge_endpoints(edge) is Some((src, dst)) else {
    abort("Illegal edge \{edge.index()}")
  }
  if vertex == src {
    // backward edge
    flow
  } else if vertex == dst {
    // forward edge
    edge_cost(edge).sub(flow)
  } else {
    abort("Illegal endpoint \{vertex.index()}")
  }
}

///|
/// The flow of `edge` after pushing `delta` towards `vertex`: pushing along a
/// forward edge increases its flow, pushing along a backward edge cancels part
/// of it.
///
/// Port of `adjust_residual_flow` / `adjusted_residual_flow` in petgraph's
/// maximum-flow modules.
fn[N, E, K : BoundedMeasure] flow_adjust_residual(
  g : @graph.Graph[N, E],
  edge : @graph.EdgeId,
  vertex : @graph.NodeId,
  flow : K,
  delta : K,
) -> K {
  guard g.edge_endpoints(edge) is Some((src, dst)) else {
    abort("Illegal edge \{edge.index()}")
  }
  if vertex == src {
    // backward edge
    flow.sub(delta)
  } else if vertex == dst {
    // forward edge
    Measure::add(flow, delta)
  } else {
    abort("Illegal endpoint \{vertex.index()}")
  }
}

///|
/// All edges incident to `vertex`, outgoing ones first, then incoming ones.
///
/// This is the MoonBit spelling of petgraph's
/// `network.edges_directed(v, Outgoing).chain(network.edges_directed(v,
/// Incoming))`: the residual network of a flow problem walks every edge in both
/// directions. For an undirected graph `edges_directed` already returns both
/// lists, so the second call is skipped to avoid visiting each edge twice.
fn[N, E] incident_edges(
  g : @graph.Graph[N, E],
  vertex : @graph.NodeId,
) -> Array[@graph.EdgeId] {
  let edges = g.edges_directed(vertex, Outgoing).to_array()
  if g.is_directed() {
    for edge in g.edges_directed(vertex, Incoming) {
      edges.push(edge)
    }
  }
  edges
}

///|
/// Breadth-first search for an augmenting path in the residual network, i.e.
/// petgraph's `has_augmented_path`.
///
/// Records in `edge_to[v]` the edge through which `v` was reached, so the caller
/// can walk the path backwards from the destination. Returns `true` as soon as
/// `destination` is reached.
fn[N, E, K : BoundedMeasure] has_augmented_path(
  g : @graph.Graph[N, E],
  source : @graph.NodeId,
  destination : @graph.NodeId,
  edge_to : Array[@graph.EdgeId?],
  flows : Array[K],
  edge_cost : (@graph.EdgeId) -> K,
) -> Bool {
  let visited = @visit.VisitMap::new(g.node_count())
  let queue : @deque.Deque[@graph.NodeId] = @deque.Deque([])
  visited.visit(source) |> ignore
  queue.push_back(source)
  let zero = Measure::zero()
  while queue.pop_front() is Some(vertex) {
    for edge in incident_edges(g, vertex) {
      let next = edge_other_endpoint(g, edge, vertex)
      let residual_cap = flow_residual_capacity(
        g,
        edge,
        next,
        flows[edge.index()],
        edge_cost,
      )
      if !visited.is_visited(next) && Measure::compare(residual_cap, zero) > 0 {
        visited.visit(next) |> ignore
        edge_to[next.index()] = Some(edge)
        if destination == next {
          return true
        }
        queue.push_back(next)
      }
    }
  }
  false
}

///|
/// [Ford-Fulkerson] algorithm in the [Edmonds-Karp] variation: computes the
/// maximum flow from `source` to `destination` in a weighted directed graph.
///
/// # Arguments
/// * `g`: a weighted directed graph (the "network").
/// * `source`: the stream *source* node.
/// * `destination`: the stream *sink* node.
/// * `edge_cost`: the capacity of each edge; capacities must be non-negative.
///
/// # Returns
/// A pair of
/// * `K`: the computed maximum flow;
/// * `Array[K]`: the flow of each edge, indexed by `EdgeId::index()`.
///
/// # Complexity
/// * Time: **O(|V||E|²)**, auxiliary space **O(|V| + |E|)**.
///
/// Direct port of petgraph's `algo::maximum_flow::ford_fulkerson`: repeatedly
/// find a shortest (in edges) augmenting path with a BFS over the residual
/// network, saturate it by its bottleneck residual capacity, and accumulate the
/// pushed flow. See also `dinics`, which solves the same problem with blocking
/// flows.
///
/// [Ford-Fulkerson]: https://en.wikipedia.org/wiki/Ford%E2%80%93Fulkerson_algorithm
/// [Edmonds-Karp]: https://en.wikipedia.org/wiki/Edmonds%E2%80%93Karp_algorithm
pub fn[N, E, K : BoundedMeasure] ford_fulkerson(
  g : @graph.Graph[N, E],
  source~ : @graph.NodeId,
  destination~ : @graph.NodeId,
  edge_cost~ : (@graph.EdgeId) -> K,
) -> (K, Array[K]) {
  let edge_to : Array[@graph.EdgeId?] = Array::make(g.node_count(), None)
  let flows : Array[K] = Array::make(g.edge_count(), Measure::zero())
  let mut max_flow = Measure::zero()
  while has_augmented_path(g, source, destination, edge_to, flows, edge_cost) {
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
      if Measure::compare(path_flow, residual_cap) > 0 {
        path_flow = residual_cap
      }
      vertex = edge_other_endpoint(g, edge, vertex)
    }
    // Update the flow of each edge along the path.
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
    max_flow = Measure::add(max_flow, path_flow)
  }
  (max_flow, flows)
}
