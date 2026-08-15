///|
/// Condense every strongly connected component into a single node and return the
/// result.
///
/// Port of petgraph's `algo::condensation`. Each node of the returned graph
/// carries the `Array[N]` of node weights of the SCC it stands for, and the SCCs
/// appear in the order produced by the SCC pass, i.e. **reverse topological
/// order**. Edge weights are carried over from the input graph, and the result
/// keeps the input's directedness.
///
/// * `make_acyclic = true`: self-loops (edges inside an SCC) are dropped and
///   parallel edges between two condensed nodes are merged via `update_edge`, so
///   the output is guaranteed to be acyclic.
/// * `make_acyclic = false`: every edge of the input is kept, so the output has
///   exactly `g.edge_count()` edges.
///
/// petgraph consumes the input graph and uses `kosaraju_scc`; this port borrows
/// the input (weights are shared, not moved) and reuses `tarjan_scc`, which
/// produces the same components in the same reverse-topological order.
///
/// # Example
/// ```mbt check
/// test {
///   // 0 <-> 1 form one SCC; 2 is on its own.
///   let g = @graph.from_edges([(0, 1), (1, 0), (1, 2)])
///   let cond = @algo.condensation(g, true)
///   debug_inspect([cond.node_count(), cond.edge_count()], content="[2, 1]")
/// }
/// ```
pub fn[N, E] condensation(
  g : @graph.Graph[N, E],
  make_acyclic : Bool,
) -> @graph.Graph[Array[N], E] {
  let sccs = tarjan_scc(g)
  let condensed : @graph.Graph[Array[N], E] = if g.is_directed() {
    @graph.Graph::with_capacity(sccs.length(), g.edge_count())
  } else {
    @graph.Graph::new_undirected()
  }

  // Build a map from old indices to new ones.
  let node_map = Array::make(g.node_count(), @graph.NodeId::new(0))
  for comp in sccs {
    let new_nix = condensed.add_node([])
    for nix in comp {
      node_map[nix.index()] = new_nix
    }
  }

  // Copy the nodes and edges of the old graph into the new one.
  for nix in g.node_ids() {
    guard g.node_weight(nix) is Some(weight) else { continue }
    guard condensed.node_weight(node_map[nix.index()]) is Some(bucket) else {
      continue
    }
    bucket.push(weight)
  }
  for edge in g.edge_ids() {
    guard g.edge_endpoints(edge) is Some((src, dst)) else { continue }
    guard g.edge_weight(edge) is Some(weight) else { continue }
    let source = node_map[src.index()]
    let target = node_map[dst.index()]
    if make_acyclic {
      if source != target {
        condensed.update_edge(source, target, weight) |> ignore
      }
    } else {
      condensed.add_edge(source, target, weight) |> ignore
    }
  }
  condensed
}
