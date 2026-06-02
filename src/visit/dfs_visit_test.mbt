///|
test "depth_first_search emits discover/finish and tree edges on a DAG" {
  let g = @graph.from_edges([(0, 1), (0, 2), (1, 3), (2, 3)])
  let events = []
  @visit.depth_first_search(g, [@graph.NodeId::new(0)], event => {
    events.push(event)
    @visit.Continue
  })
  debug_inspect(
    events,
    content=(
      #|[
      #|  Discover(NodeId(0), 0),
      #|  TreeEdge(NodeId(0), NodeId(2)),
      #|  Discover(NodeId(2), 1),
      #|  TreeEdge(NodeId(2), NodeId(3)),
      #|  Discover(NodeId(3), 2),
      #|  Finish(NodeId(3), 3),
      #|  Finish(NodeId(2), 4),
      #|  TreeEdge(NodeId(0), NodeId(1)),
      #|  Discover(NodeId(1), 5),
      #|  CrossForwardEdge(NodeId(1), NodeId(3)),
      #|  Finish(NodeId(1), 6),
      #|  Finish(NodeId(0), 7),
      #|]
    ),
  )
}

///|
test "depth_first_search detects a back edge in a cyclic graph" {
  // 0 -> 1 -> 2 -> 0 forms a cycle; the edge 2 -> 0 is a back edge.
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 0)])
  let back_edges = []
  @visit.depth_first_search(g, [@graph.NodeId::new(0)], event => {
    if event is BackEdge(u, v) {
      back_edges.push((u.index(), v.index()))
    }
    @visit.Continue
  })
  json_inspect(back_edges, content=[[2, 0]])
}

///|
test "depth_first_search Break stops the traversal early" {
  let g = @graph.from_edges([(0, 1), (1, 2), (2, 3)])
  let discovered = []
  @visit.depth_first_search(g, [@graph.NodeId::new(0)], event => {
    match event {
      Discover(n, _) => {
        discovered.push(n.index())
        // Stop as soon as we discover node 2.
        if n.index() == 2 {
          @visit.Break
        } else {
          @visit.Continue
        }
      }
      _ => @visit.Continue
    }
  })
  json_inspect(discovered, content=[0, 1, 2])
}

///|
test "depth_first_search Prune skips edges out of a node" {
  let g = @graph.from_edges([(0, 1), (0, 2), (1, 3)])
  let discovered = []
  @visit.depth_first_search(g, [@graph.NodeId::new(0)], event => {
    match event {
      Discover(n, _) => {
        discovered.push(n.index())
        // Prune node 1: do not traverse 1 -> 3, so node 3 is never discovered.
        if n.index() == 1 {
          @visit.Prune
        } else {
          @visit.Continue
        }
      }
      _ => @visit.Continue
    }
  })
  // Neighbors of 0 are [2, 1]; we visit 0, 2, then 1 (pruned), never 3.
  json_inspect(discovered, content=[0, 2, 1])
}
