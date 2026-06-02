///|
/// Demo for the MoonBit port of petgraph.
///
/// Mirrors petgraph's own README example: build an undirected graph, run
/// Dijkstra's shortest path, compute a minimum spanning tree, and print the
/// result in Graphviz DOT format.
fn main {
  // An undirected graph with `Int` node weights and `Int` edge weights.
  //
  //   0 -- 1
  //   |    |
  //   3 -- 2
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let n0 = g.add_node(0)
  let n1 = g.add_node(1)
  let n2 = g.add_node(2)
  let n3 = g.add_node(3)
  let _ = g.add_edge(n0, n1, 1)
  let _ = g.add_edge(n1, n2, 1)
  let _ = g.add_edge(n2, n3, 1)
  let _ = g.add_edge(n0, n3, 1)

  println("Graph: \{g.node_count()} nodes, \{g.edge_count()} edges")

  // Shortest path distances from node 0, using each edge's weight as its cost.
  let dist = @algo.dijkstra(g, start=n0, edge_cost=fn(e) {
    g.edge_weight(e).unwrap()
  })
  println("Dijkstra distances from node 0:")
  for n in g.node_ids() {
    let d = match dist.get(n) {
      Some(v) => v.to_string()
      None => "unreachable"
    }
    println("  node \{n.index()} -> \{d}")
  }

  // Minimum spanning tree (Kruskal). The 4-cycle drops exactly one edge.
  let mst = @algo.min_spanning_tree(g, edge_cost=fn(e) {
    g.edge_weight(e).unwrap()
  })
  println("MST keeps \{mst.length()} of \{g.edge_count()} edges")

  // Render the original graph as Graphviz DOT.
  println("DOT:")
  println(@dot.to_dot(g))
}
